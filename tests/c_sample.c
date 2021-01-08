// Important Notice: You must use --threads:on AND you need to avoid --gc:arc ; I had crashes on windows otherwise with NIM 1.4 when starting webview

// nim c --verbosity:2  --threads:on -d:release -d:useStdLib --noMain --noLinking --header:nimvue.h --nimcache=./tmp_c nimvue.nim
// gcc -c -w -o tmp_c/c_sample.o -fmax-errors=3 -mno-ms-bitfields -DWIN32_LEAN_AND_MEAN -DWEBVIEW_STATIC -DWEBVIEW_IMPLEMENTATION -IC:\Users\Mmengelkoch\.nimble\pkgs\webview-0.1.0\webview -DWEBVIEW_WINAPI=1 -O3 -fno-strict-aliasing -fno-ident -IC:\Users\Mmengelkoch\.choosenim\toolchains\nim-1.4.2\lib -Itmp_c tests/c_sample.c
// gcc -w -o tests/c_sample.exe tmp_c/*.o -lole32 -lcomctl32 -loleaut32 -luuid -lgdi32 -Itmp_c
// 
// nim cpp --threads:on --verbosity:2 -d:debug --debuginfo  --debugger:native -d:useStdLib --noMain --noLinking --header:nimvue.h --nimcache=./tmp_c nimvue.nim
// cp .\generated_c\nimvue.h . 
// cd tests
// // g++ -o c_sample -Inimcache -IC:/Users/Mmengelkoch/.choosenim/toolchains/nim-1.4.2/lib -L../. -lnimvue c_sample.c
// // g++.exe -c -w -o tmp_c/c_sample.o -std=gnu++14 -funsigned-char  -w -fmax-errors=3 -fpermissive -mno-ms-bitfields -DWIN32_LEAN_AND_MEAN -DWEBVIEW_STATIC -DWEBVIEW_IMPLEMENTATION -IC:\Users\Mmengelkoch\.nimble\pkgs\webview-0.1.0\webview -DWEBVIEW_WINAPI=1 -g3 -Og   -IC:\Users\Mmengelkoch\.choosenim\toolchains\nim-1.4.2\lib -IE:\apps\nimvue -Itmp_c tests/c_sample.cpp
#include "../tmp_c/nimvue.h"
#include <stdio.h>
#include <stdlib.h>
// #include <iostream>
// extern void startWebviewC(char*);

char* str_concat(const char *s1, const char *s2)
{
    char *result = malloc(strlen(s1) + strlen(s2) + 1); // +1 for the null-terminator
    if (result) {
        strcpy(result, s1); // safe
        strcat(result, s2); // safe
    }
    return result;
}

char* appendSomething(char* something) {
    return str_concat(something, " modified by C");
}
int main(int argc, char* argv[]) {
    printf(" starting c code\n");
    NimMain();
    
    nimvue_addRequest("appendSomething", appendSomething, free);
    printf(" 3 ... \n");
    nimvue_startWebview("E:/apps/nimvue/tests/vue/dist/index.html");
    printf(" 4 ... \n");
    nimvue_startJester("E:/apps/nimvue/tests/vue/dist/index.html", 8000, "127.0.0.1");
    printf(" ... finished \n");
}
