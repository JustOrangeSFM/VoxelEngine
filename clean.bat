@echo off
echo Cleaning VoxelEngine...

if exist build (
    echo Removing build/
    rmdir /s /q build
)

if exist build_debug (
    echo Removing build_debug/
    rmdir /s /q build_debug
)


if exist bin (
    echo Removing bin/
    rmdir /s /q bin
)

if exist compile_commands.json (
    echo Removing compile_commands.json
    del compile_commands.json
)

echo Clean completed!