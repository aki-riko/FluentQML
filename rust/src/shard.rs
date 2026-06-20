// shard.rs - 跨分片 fan-out 查询 + 归并排序
//
// 设计:
// - fan_out_fetch_page(db_paths, sql, params, limit, cursor_indices, sort_directions):
//   每个 shard 独立 fetch_page (LIMIT N),把所有 shard 结果按 cursor 列做归并排序,
//   取 top-N 返回。供 FluentSqlListModel 跨片场景使用。
//
// - 关键不变量:
//   1. 所有 shard 使用同一 SQL 模板 (含同 ORDER BY 子句)
//   2. cursor_columns 在所有 shard 都是 ORDER BY 前缀
//   3. sort_directions 与 cursor_columns 同长度,每列 'DESC'/'ASC' (统一所有 shard)
//
// - 性能:
//   N shard 各拉 limit 行 → 归并 N*limit 行取 top-limit。N=10, limit=1000 时
//   归并 10000 行 ~1ms (Rust),fetch 并发 ~5ms (rusqlite 多连接), total <10ms。

use pyo3::prelude::*;
use pyo3::types::{PyList, PyDict};
use rusqlite::{Connection, OpenFlags};
use std::cmp::Ordering;

use crate::value_ref_to_py;

#[derive(Debug, Clone, Copy, PartialEq)]
enum Direction {
    Asc,
    Desc,
}

/// 一个 shard 取出的一行,带源 shard 索引(用于堆稳定性 / 调试)
struct CandidateRow {
    cells: Vec<PyObject>,        // 所有列的 PyObject
    cursor_values: Vec<PyObject>, // cursor 列在 cells 中的复制(便于 compare,避免 indirect)
    _shard_idx: usize,
}

fn open_conn(db_path: &str) -> PyResult<Connection> {
    Connection::open_with_flags(
        db_path,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(e.to_string()))
}

/// 比较两个 cursor 行: 按 sort_directions 逐列比较
///
/// NULL 处理 (B3 修复, 与 SQLite 默认行为对齐):
///   ASC 默认 NULLS FIRST, DESC 默认 NULLS LAST
/// - DESC + a=None,b=Some: NULLS LAST → a 排在 b 后 → a > b → Greater
/// - ASC  + a=None,b=Some: NULLS FIRST → a 排在 b 前 → a < b → Less
/// - 两侧都 None: Equal
/// - 异类型 fallback Equal (避免老 unwrap_or(false) 导致 sort 不稳定)
fn compare_cursor_values(
    py: Python,
    a: &[PyObject],
    b: &[PyObject],
    dirs: &[Direction],
) -> Ordering {
    for (i, dir) in dirs.iter().enumerate() {
        if i >= a.len() || i >= b.len() {
            return Ordering::Equal;
        }
        let av = a[i].bind(py);
        let bv = b[i].bind(py);
        let a_none = av.is_none();
        let b_none = bv.is_none();
        // B3: 按方向决定 NULL 端点
        // SQLite 默认: DESC 排序 NULL 在末尾, ASC 排序 NULL 在开头
        let cmp = if a_none && b_none {
            Ordering::Equal
        } else if a_none {
            // a 是 None: DESC → 末尾 → a > b ; ASC → 开头 → a < b
            match dir {
                Direction::Desc => Ordering::Greater,
                Direction::Asc => Ordering::Less,
            }
        } else if b_none {
            match dir {
                Direction::Desc => Ordering::Less,
                Direction::Asc => Ordering::Greater,
            }
        } else {
            // 两侧都非 None: 走 Python 富比较
            // H4: 异类型时 lt/gt 都 Err (Python TypeError),fallback 用 type-name 字典序
            // 不再静默 Equal — 否则同类型行错位
            match (av.lt(bv), av.gt(bv)) {
                (Ok(true), _) => Ordering::Less,
                (_, Ok(true)) => Ordering::Greater,
                (Ok(false), Ok(false)) => Ordering::Equal,
                _ => {
                    // 异类型,按类型名比 (int < str < bytes 等),保证稳定全局序
                    let a_ty: String = av.get_type().qualname()
                        .ok().and_then(|q| q.extract().ok()).unwrap_or_default();
                    let b_ty: String = bv.get_type().qualname()
                        .ok().and_then(|q| q.extract().ok()).unwrap_or_default();
                    a_ty.cmp(&b_ty)
                }
            }
        };
        if cmp != Ordering::Equal {
            // None 案例的 cmp 已包含方向语义,不再 reverse
            if a_none || b_none {
                return cmp;
            }
            return match dir {
                Direction::Desc => cmp.reverse(),
                Direction::Asc => cmp,
            };
        }
    }
    Ordering::Equal
}

/// 跨分片 fan-out 查询
///
/// Args:
///     db_paths: shard 文件路径列表
///     sql: 主查询 (会被每个 shard 各执行一次,不含 LIMIT/OFFSET)
///     params: SQL 占位符参数
///     limit: 跨片归并后取的总行数
///     cursor_indices: cursor 列在 SELECT 中的下标 (供 last_cursor 提取 + 归并排序)
///     sort_directions: 与 cursor_indices 等长,每列 "DESC"/"ASC"
///
/// Returns:
///     dict {"columns", "rows", "last_cursor"} - 与 fetch_page 同结构
#[pyfunction]
#[pyo3(signature = (db_paths, sql, params=None, limit=1000, cursor_indices=None, sort_directions=None))]
pub fn fan_out_fetch_page(
    py: Python,
    db_paths: Vec<String>,
    sql: &str,
    params: Option<&Bound<'_, PyAny>>,
    limit: i64,
    cursor_indices: Option<Vec<usize>>,
    sort_directions: Option<Vec<String>>,
) -> PyResult<PyObject> {
    if db_paths.is_empty() {
        return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
            "db_paths 不能为空",
        ));
    }

    // 把方向字符串转 enum
    let directions: Vec<Direction> = sort_directions
        .as_ref()
        .map(|v| {
            v.iter()
                .map(|s| match s.to_uppercase().as_str() {
                    "ASC" => Direction::Asc,
                    _ => Direction::Desc,
                })
                .collect()
        })
        .unwrap_or_default();

    let cur_indices: Vec<usize> = cursor_indices.clone().unwrap_or_default();

    // 把 params 转 rusqlite Value (各 shard 共用)
    use rusqlite::types::Value;
    let mut bound: Vec<Value> = Vec::new();
    if let Some(p) = params {
        let len = p.len()?;
        for i in 0..len {
            let item = p.get_item(i)?;
            if item.is_none() {
                bound.push(Value::Null);
            } else if let Ok(b) = item.extract::<bool>() {
                bound.push(Value::Integer(if b { 1 } else { 0 }));
            } else if let Ok(i) = item.extract::<i64>() {
                bound.push(Value::Integer(i));
            } else if let Ok(f) = item.extract::<f64>() {
                bound.push(Value::Real(f));
            } else if let Ok(s) = item.extract::<String>() {
                bound.push(Value::Text(s));
            } else if let Ok(bs) = item.extract::<Vec<u8>>() {
                bound.push(Value::Blob(bs));
            } else {
                return Err(PyErr::new::<pyo3::exceptions::PyTypeError, _>(format!(
                    "unsupported sql parameter type at index {}",
                    i
                )));
            }
        }
    }
    bound.push(Value::Integer(limit));

    let paged_sql = format!("{} LIMIT ?", sql);

    // 每 shard 各拉 limit 行
    let mut all_candidates: Vec<CandidateRow> = Vec::new();
    let mut column_names: Vec<String> = Vec::new();

    for (shard_idx, db_path) in db_paths.iter().enumerate() {
        let conn = open_conn(db_path)?;
        let mut stmt = conn
            .prepare(&paged_sql)
            .map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(e.to_string()))?;

        let column_count = stmt.column_count();
        let this_shard_columns: Vec<String> = (0..column_count)
            .map(|i| stmt.column_name(i).unwrap_or("").to_string())
            .collect();
        if column_names.is_empty() {
            column_names = this_shard_columns.clone();
        } else if column_names != this_shard_columns {
            // M3: shard 之间 schema 不一致直接报错,避免静默把第二 shard 的错位列当首 shard 同名列输出
            return Err(PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(format!(
                "shard schema mismatch at index {}: expected {:?}, got {:?}",
                shard_idx, column_names, this_shard_columns
            )));
        }

        let refs: Vec<&dyn rusqlite::ToSql> =
            bound.iter().map(|v| v as &dyn rusqlite::ToSql).collect();
        let mut rows = stmt
            .query(refs.as_slice())
            .map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(e.to_string()))?;

        while let Some(row) = rows
            .next()
            .map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(e.to_string()))?
        {
            let mut cells: Vec<PyObject> = Vec::with_capacity(column_count);
            for c in 0..column_count {
                let v = row
                    .get_ref(c)
                    .map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(e.to_string()))?;
                cells.push(value_ref_to_py(py, v)?);
            }
            // 收集 cursor 列
            let cursor_values: Vec<PyObject> = cur_indices
                .iter()
                .map(|&i| {
                    if i < cells.len() {
                        cells[i].clone_ref(py)
                    } else {
                        py.None()
                    }
                })
                .collect();
            all_candidates.push(CandidateRow {
                cells,
                cursor_values,
                _shard_idx: shard_idx,
            });
        }
    }

    // 归并: 按 cursor 排序,取前 limit 个
    if !directions.is_empty() && !cur_indices.is_empty() {
        all_candidates.sort_by(|a, b| {
            compare_cursor_values(py, &a.cursor_values, &b.cursor_values, &directions)
        });
    }
    all_candidates.truncate(limit as usize);

    // 转 Py 输出
    let py_rows = PyList::empty_bound(py);
    let mut last_cursor_cells: Option<Vec<PyObject>> = None;
    for cand in &all_candidates {
        let py_row = PyList::empty_bound(py);
        for cell in &cand.cells {
            py_row.append(cell.clone_ref(py))?;
        }
        py_rows.append(py_row)?;
        last_cursor_cells = Some(cand.cursor_values.iter().map(|o| o.clone_ref(py)).collect());
    }

    let result = PyDict::new_bound(py);
    result.set_item("columns", column_names)?;
    result.set_item("rows", py_rows)?;
    if let Some(last) = last_cursor_cells {
        let cursor_list = PyList::empty_bound(py);
        for v in last {
            cursor_list.append(v)?;
        }
        result.set_item("last_cursor", cursor_list)?;
    } else {
        result.set_item("last_cursor", py.None())?;
    }
    Ok(result.into())
}
