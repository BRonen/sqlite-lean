import Lake
open System Lake DSL

package sqlite

lean_lib SQLite

def compiler := (·.getD "cc") <$> IO.getEnv "CC"

target sqlite.o pkg : FilePath := do
  let oFile := pkg.buildDir / "sqlite3.o"
  let srcJob ← inputTextFile <| pkg.dir / "native" / "sqlite3.c"
  let sqliteHeaders := pkg.dir / "native"
  -- Ensure that both sqlite3.h and sqlite3ext.h are available during compilation
  let weakArgs := #["-I", sqliteHeaders.toString]
  buildO oFile srcJob weakArgs #["-fPIC"] (← compiler) getLeanTrace

target sqliteffi.o pkg : FilePath := do
  let oFile := pkg.buildDir  / "sqliteffi.o"
  let srcJob ← inputTextFile <| pkg.dir / "native" / "sqliteffi.c"
  let sqliteHeaders := pkg.dir / "native"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString, "-I", sqliteHeaders.toString]
  buildO oFile srcJob weakArgs #["-fPIC"] (← compiler) getLeanTrace

extern_lib libsqlite pkg := do
  let sqliteO ← sqlite.o.fetch
  let ffiO ← sqliteffi.o.fetch
  let name := nameToStaticLib "sqliteffi"
  buildStaticLib (pkg.staticLibDir / name) #[sqliteO, ffiO]

@[default_target]
lean_exe sqlite where
  root := `Main
  moreLinkObjs := #[libsqlite]
  moreLinkArgs := if !Platform.isWindows then #["-Wl,--unresolved-symbols=ignore-all"] else #[] -- TODO: Very gross hack

@[test_driver]
lean_exe Tests.SQLite where
  buildType := .debug
  moreLinkObjs := #[libsqlite]
  moreLinkArgs := if !Platform.isWindows then #["-Wl,--unresolved-symbols=ignore-all"] else #[] -- Same as above

require LSpec from git
  "https://github.com/argumentcomputer/lspec/" @ "1fc461a9b83eeb68da34df72cec2ef1994e906cb"
