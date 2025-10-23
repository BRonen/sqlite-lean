# SQLite Lean

## How to use/build
1. First, you are going to want to set the enviromental variable CC in order to build this library.
    - Due to a [limitation with leanc](https://github.com/leanprover/lean4/issues/10831), we cannot use the bundled-in version of clang that comes with Lean in order to build this library.
    - Instead we will have to use a seperate C compiler to link SQLite with our Lean code
    - On Windows you can use [w64devkit](https://github.com/skeeto/w64devkit), and then set CC like so
        ```
        $Env:CC = "C:\github\w64devkit\w64devkit\bin\gcc.exe"
        ```
        Or wherever the version of gcc that comes with w64devkit is located
    - You can later remove this enviromental variable if you don't want to clutter your terminal like so
        ```
        Remove-Item Env:CC
        ```
2. Then, you should be able to do ``lake test`` to see the library build properly
3. If you want to use this library with your own code, make sure you are passing the exact same ``moreLinkArgs`` that this library has
    - ``moreLinkArgs`` are not inherited by child projects
    - Currently, that looks something like this 
    ```lean
    moreLinkArgs := if !Platform.isWindows then #["-Wl,--unresolved-symbols=ignore-all"] else #[] -- TODO: Very gross hack 
    ```

## Notes

Uses the [amalgamation](https://sqlite.org/amalgamation.html) of [SQLite](https://sqlite.org/), which bundles all of SQLite into one .c file for easy compilation.
