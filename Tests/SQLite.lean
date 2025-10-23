import LSpec
import SQLite

open LSpec
open SQLite.FFI
open SQLite.FFI.Constants

instance (b : Bool) : Testable b :=
  if h : b = true then
    .isTrue h
  else
    .isFalse h s!"Expected true but got false"

structure TestContext where
  conn : Connection

def setup (s : String) : IO TestContext := do
  let flags := SQLITE_OPEN_READWRITE ||| SQLITE_OPEN_CREATE
  let conn ← connect s flags
  match ← conn.prepare "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, height REAL) STRICT;" with
  | Except.ok cursor => cursor.step
  | Except.error _ => pure false
  match ← conn.prepare "INSERT INTO users (id, name, height) VALUES (1, 'John Doe', 2.3);" with
  | Except.ok cursor => cursor.step
  | Except.error _ => pure false
  return ⟨conn⟩

def cleanup (ctx : TestContext) : IO Unit := do
  match ← ctx.conn.prepare "DROP TABLE IF EXISTS users;" with
  | Except.ok cursor => do
    let _ ← cursor.step
    return ()
  | Except.error _ => return ()

def withTest (test : TestContext → IO Bool) : IO Bool := do
  let ctx ← setup "test.sqlite3"
  try
    let result ← test ctx
    cleanup ctx
    return result
  catch e =>
    IO.println s!"Error: {e}"
    cleanup ctx
    return false

def testSelectData (ctx : TestContext) : IO Bool := do
  match ← ctx.conn.prepare "SELECT * FROM users WHERE id = 1;" with
  | Except.ok cursor =>
    let hasRow ← cursor.step
    if hasRow then
      let id ← cursor.columnInt 0
      let name ← cursor.columnText 1
      let height ← cursor.columnDouble 2
      return id == 1 && name == "John Doe" && height == 2.3
    else
      return false
  | Except.error err => throw <| .userError err

def testInsertData (ctx : TestContext) : IO Bool := do
  let id := -2 ^ 63 |>.toInt64
  let name := "Jane Doe"
  let height := 20.25
  match ← ctx.conn.prepare "INSERT INTO users (id, name, height) VALUES (?, ?, ?);" with
  | Except.ok cursor =>
    cursor.bindInt64 1 id
    cursor.bindText 2 name
    cursor.bindDouble 3 height
    let _ ← cursor.step -- This always returns false
  | Except.error err => throw <| .userError err
  match ← ctx.conn.prepare "SELECT * FROM users WHERE id = ?;" with
  | Except.ok cursor =>
    cursor.bindInt64 1 id
    let hasRow ← cursor.step
    if hasRow then
      let id' ← cursor.columnInt64 0
      let name' ← cursor.columnText 1
      let height' ← cursor.columnDouble 2
      return id == id' && name == name' && height == height'
    else
      return false
  | Except.error err => throw <| .userError err

def testParameterBinding (ctx : TestContext) : IO Bool := do
  match ← ctx.conn.prepare "SELECT * FROM users WHERE id > ? AND name = ?;" with
  | Except.ok cursor =>
    cursor.bindInt 1 0
    cursor.bindText 2 "John Doe"
    return true
  | Except.error err => throw <| .userError err

def testColumnCount (ctx : TestContext) : IO Bool := do
  match ← ctx.conn.prepare "SELECT * FROM users;" with
  | Except.ok cursor =>
    let count ← cursor.columnsCount
    return count == 3
  | Except.error err => throw <| .userError err

def testInvalidSyntax (ctx : TestContext) : IO Bool :=
  return match ← ctx.conn.prepare "INVALID SQL QUERY;" with
  | Except.error _ => true
  | Except.ok _ => false

def testNonExistentTable (ctx : TestContext) : IO Bool :=
  return match ← ctx.conn.prepare "SELECT * FROM non_existent_table;" with
  | Except.error _ => true
  | Except.ok _ => false

def main (args : List String) := do
  lspecIO (.ofList [("test suite", [
    test "can select data" (← withTest testSelectData),
    test "can insert data" (← withTest testInsertData),
    test "can bind parameters" (← withTest testParameterBinding),
    test "can get column count" (← withTest testColumnCount),
    test "handles invalid SQL syntax" (← withTest testInvalidSyntax),
    test "handles non-existent table" (← withTest testNonExistentTable)
  ])]) args
