/** Nimview UI Library 
 * Copyright (C) 2020, 2021, by Marco Mengelkoch
 * Licensed under MIT License, see License file for more details
 * git clone https://github.com/marcomq/nimview
**/
#pragma once
#ifndef NIMVIEW_CUSTOM_LIB
extern "C" {
#include "nimview.h"
}
#endif
#include <string>
#include <sstream>
#include <map>
#include <type_traits>
#include <utility>
#include <functional>
#include <stdlib.h>
#ifdef _MSC_VER 
#include <variant>
#endif
#define addRequest(...) addRequestImpl<__COUNTER__, std::string>(__VA_ARGS__) 

// typedef void (*requestFunction)(const char*);

template<typename Lambda>
union FunctionStorage {
    FunctionStorage() {};
    std::decay_t<Lambda> lambdaFunction;
    ~FunctionStorage() {};
};


template<unsigned int COUNTER, typename Lambda, typename Result, typename... Args>
auto functionPointerWrapper(Lambda&& callback, Result(*)(Args...)) {
    static FunctionStorage<Lambda> storage;
    using type = decltype(storage.lambdaFunction);

    static bool used = false;
    if (used) {
        storage.lambdaFunction.~type(); // overwrite
    }
    new (&storage.lambdaFunction) type(std::forward<Lambda>(callback));
    used = true;

    return [](Args... args)->Result {
        return Result(storage.lambdaFunction(std::forward<Args>(args)...));
    };
}

template<unsigned int COUNTER, typename Fn = char* (int argc, char** argv), typename Lambda>
Fn* castToFunction(Lambda&& memberFunction) {
    return functionPointerWrapper<COUNTER>(std::forward<Lambda>(memberFunction), (Fn*)nullptr);
}

namespace nimview {
    thread_local bool nimInitialized = false;
    void nimMain() {
        if (!nimInitialized) {
            ::NimMain();
            nimInitialized = true;
        }
    };
    template <typename T>
    T lexicalCast(const char* str) {
        T var;
        std::istringstream iss;
        iss.str(str);
        iss >> var;
        return var;
    }
    template<unsigned int COUNTER, typename T1, typename T2, typename T3> 
    void addRequestImpl(const std::string &request, const std::function<std::string(T1, T2, T3)> &callback) {
        auto lambda = [&, callback](int argc, char** argv) {
            if (argc < 3) {
                throw std::runtime_error("Not enough arguments");
            }
            std::string result = callback(lexicalCast<T1>(argv[1]),lexicalCast<T2>(argv[2]), lexicalCast<T3>(argv[3]));
            if (result == "") {
                return const_cast<char*>(""); // "" will not be freed
            }
            else {
                char* newChars = static_cast<char*>(calloc(result.length() + 1, 1));
                result.copy(newChars, result.length());
                return newChars;
            }
        };
        auto cFunc = castToFunction<COUNTER>(lambda);
        addRequest_argc_argv(const_cast<char*>(request.c_str()), cFunc, free);
    }
    template<unsigned int COUNTER, typename T1, typename T2 = std::string> 
    void addRequestImpl(const std::string &request, const std::function<std::string(T1, T2)> &callback) {
        auto lambda = [&, callback](int argc, char** argv) {
            if (argc < 2) {
                throw std::runtime_error("Not enough arguments");
            }
            std::string result = callback(lexicalCast<T1>(argv[1]),lexicalCast<T2>(argv[2]));
            if (result == "") {
                return const_cast<char*>(""); // "" will not be freed
            }
            else {
                char* newChars = static_cast<char*>(calloc(result.length() + 1, 1));
                result.copy(newChars, result.length());
                return newChars;
            }
        };
        auto cFunc = castToFunction<COUNTER>(lambda);
        addRequest_argc_argv(const_cast<char*>(request.c_str()), cFunc, free);
    }
    template<unsigned int COUNTER, typename T1 = const std::string&> 
    void addRequestImpl(const std::string &request, const std::function<std::string(T1)> &callback) {
        auto lambda = [&, callback](int argc, char** argv) {
            if (argc < 1) {
                throw std::runtime_error("Not enough arguments");
            }
            std::string result = callback(lexicalCast<T1>(argv[1]));
            if (result == "") {
                return const_cast<char*>(""); // "" will not be freed
            }
            else {
                char* newChars = static_cast<char*>(calloc(result.length() + 1, 1));
                result.copy(newChars, result.length());
                return newChars;
            }
        };
        auto cFunc = castToFunction<COUNTER>(lambda);
        addRequest_argc_argv(const_cast<char*>(request.c_str()), cFunc, free);
    }
    void addRequest2(const std::string &request, const std::function<std::string(const std::string&)> &callback) {
        addRequestImpl<__COUNTER__, std::string>(request, callback);
    }

#ifndef JUST_CORE
    void startDesktop(const char* folder, const char* title = "nimview", int width = 640, int height = 480, bool resizable = true, bool debug = false)  {
        nimMain(); 
        ::startDesktop(const_cast<char*>(folder), const_cast<char*>(title), width, height, resizable, debug);
    };
    void startHttpServer(const char* folder, int port = 8000, const char* bindAddr = "localhost")  { 
        nimMain();
        ::startHttpServer(const_cast<char*>(folder), port, const_cast<char*>(bindAddr));
    };
    void start(const char* folder, int port = 8000, const char* bindAddr = "localhost", const char* title = "nimview", int width = 640, int height = 480, bool resizable = true)  {
        nimMain();
        #ifdef _WIN32
            bool runWithGui = true;
        #else
            bool runWithGui = (NULL != getenv("DISPLAY"));
        #endif
        #ifdef _DEBUG
            runWithGui = false;
        #endif
        if (runWithGui) {
            nimview::startDesktop(const_cast<char*>(folder), const_cast<char*>(title), width, height, resizable, false);
        }
        else {
            nimview::startHttpServer(const_cast<char*>(folder), port, const_cast<char*>(bindAddr));
        }
    }
#endif
    char* dispatchRequest(char* request, char* value) {
        nimMain();
        return ::dispatchRequest(request, value);
    };
    std::string dispatchRequest(const std::string &request, const std::string &value) {
        nimMain();
        // free of return value should be performed by nim gc
        return ::dispatchRequest(const_cast<char*>(request.c_str()), const_cast<char*>(value.c_str())); 
    };
    auto dispatchCommandLineArg = ::dispatchCommandLineArg;
    auto readAndParseJsonCmdFile = ::readAndParseJsonCmdFile;
    auto enableStorage = ::enableStorage;
    auto stopHttpServer = ::stopHttpServer;
    auto stopDesktop = ::stopDesktop;
    
}
