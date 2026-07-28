#ifndef COMPILER_COMMON_H
#define COMPILER_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
/* Add what you need */

typedef struct {
    int index;       // 符號表索引
    char *name;      // 變數名
    char *type;      // 類型 (i32, f32, bool, str, array, func)
    int is_mutable;  // 0=不可變, 1=可變, -1=函數
    int address;     // 記憶體位址
    int lineno;      // 宣告行號
    char *func_sig;  // 函數簽名，否則為 "-"
} Symbol;

typedef struct SymbolTable {
    Symbol symbols[100]; // 每個 scope 最多 100 個變數
    int count;           // 當前變數數量
    int level;           // scope 層級
    struct SymbolTable *parent; // 指向父 scope
} SymbolTable;


#endif /* COMPILER_COMMON_H */