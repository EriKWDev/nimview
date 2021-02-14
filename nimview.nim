# Nimview UI Library 
# Copyright (C) 2021, by Marco Mengelkoch
# Licensed under MIT License, see License file for more details
# git clone https://github.com/marcomq/nimview

import os
import json
import system
import uri
import strutils
import tables
import logging

const compileWithWebview = defined(useWebview) or not defined(useJester)

when not defined(just_core):
  import jester
  import nimpy
  when compileWithWebview:
    import webview except debug
    var myWebView: Webview
  # import browsers
else:
  # Just core features. Disable jester, webview nimpy and exportpy
  macro exportpy(def: untyped): untyped =
    result = def

# nim c -r --threads:on -d:debug --debuginfo  --debugger:native -d:useStdLib --verbosity:2 nimview.nim
# cp .\generated_c\nimview.h .
# nim c --verbosity:2 -d:release -d:useStdLib --header:nimview.h --app:lib --out:nimview.dll --nimcache=./tmp_c nimview.nim
# nim c --verbosity:2 -d:release -d:useStdLib --header:nimview.h --nimcache=./tmp_c nimview.nim
# nim c --verbosity:2 -d:release -d:useStdLib --noMain:on --noLinking:on  --compileOnly:on --header:nimview.h --nimcache=./tmp_c nimview.nim
# nim c --verbosity:2 -d:release -d:useStdLib --noMain:on -d:noMain --noLinking:on --header:nimview.h --nimcache=./tmp_c nimview.nim    
# gcc -c -w -o tmp_c/c_sample.o -fmax-errors=3 -mno-ms-bitfields -DWIN32_LEAN_AND_MEAN -DWEBVIEW_STATIC -DWEBVIEW_IMPLEMENTATION -DWEBVIEW_WINAPI=1 -O3 -fno-strict-aliasing -fno-ident -IC:\Users\Mmengelkoch\.nimble\pkgs\webview-0.1.0\webview -IC:\Users\Mmengelkoch\.choosenim\toolchains\nim-1.4.2\lib -Itmp_c tests/c_sample.c
# gcc -w -o tests/c_sample.exe tmp_c/*.o -lole32 -lcomctl32 -loleaut32 -luuid -lgdi32 -Itmp_c 

type ReqUnknownException* = object of CatchableError
type RequestCallbacks* = object of RootObj
  map: Table[string, proc(value: string): string ]

var req*: ptr RequestCallbacks = system.createShared(RequestCallbacks)
var responseHttpHeader = {"Access-Control-Allow-Origin": "None"} # will be overwritten when starting Jester
var useJester* = not compileWithWebview or (defined(useJester) or defined(debug) or (fileExists("/.dockerenv")))

let stdLogger = newConsoleLogger()
logging.addHandler(stdLogger)
var requestLogger: FileLogger = nil

proc enableRequestLogger*() {.exportpy.} = 
  if requestLogger.isNil:
    if not fileExists("requests.log"):
      var createFile = system.open("requests.log", system.fmWrite)
      createFile.close()
    let requestLoggerTmp = newFileLogger("requests.log", fmtStr = "")
    requestLogger = requestLoggerTmp;
  requestLogger.levelThreshold = logging.lvlAll
    
proc disableRequestLogger*() {.exportpy.} = 
  if not requestLogger.isNil:
    requestLogger.levelThreshold = logging.lvlNone

proc addRequest*(request: string, callback: proc(value: string): string ) {.exportpy.} = 
  {.gcsafe.}:
    req.map[request] = callback

proc dispatchRequest*(request, value: string): string {.exportpy.} = 
  {.gcsafe.}:
    if req.map.hasKey(request):
      let callbackFunc = req.map[request]
      result = callbackFunc(value) 
    else :
      raise newException(ReqUnknownException, "404 - Request unknown")

# main dispatcher
# used by webview AND jester
proc dispatchJsonRequest*(jsonMessage: JsonNode): string = 
  var value = $jsonMessage["value"].getStr() 
  if (value == ""):
    value = $jsonMessage["value"]
  let request = $jsonMessage["request"].getStr()
  {.gcsafe.}:
    if not requestLogger.isNil:
      requestLogger.log(logging.lvlInfo, $jsonMessage)
  result = dispatchRequest(request, value)

proc dispatchCommandLineArg*(escapedArgv: string): string = 
  try:
    let jsonMessage = parseJson(escapedArgv)
    result = dispatchJsonRequest(jsonMessage)
  except ReqUnknownException:
    warn "Request is unknown in " & escapedArgv
  except: 
    warn "Couldn't parse specific line arg: " & escapedArgv

proc readAndParseJsonCmdFile*(filename: string) = 
  if (os.fileExists(filename)):
    debug "opening file for parsing: " & filename
    let file = system.open(filename, system.FileMode.fmRead)
    var line: TaintedString
    while (file.readLine(line)):
      # TODO: escape line if source file cannot be trusted
      let retVal = nimview.dispatchCommandLineArg(line.string)
      debug retVal
    close(file)
  else:
    logging.error "File does not exist: " & filename

when not defined(just_core):
  when defined release:
    const backendHelperJs = system.staticRead("backend-helper.js")
  else:
    var backendHelperJs = system.readFile("backend-helper.js")

  proc dispatchHttpRequest*(jsonMessage: JsonNode, headers: HttpHeaders): string = 
    # optional but not implemented yet - check credentials from header information
    result = dispatchJsonRequest(jsonMessage)

  template respond(code: untyped, message: untyped): untyped =
    mixin resp
    {.gcsafe.}:
      resp code, nimview.responseHttpHeader, message
  
  template respond(message: untyped): untyped =
      respond Http200, message

  proc handleRequest(request: Request): Future[ResponseData] {.async.} =
    block route:
      var response: string
      var requestPath: string = request.pathInfo 
      var resultId = 0
      case requestPath
      of "/backend-helper.js":
        respond nimview.backendHelperJs
      else:
        try:
          if (requestPath == "/"): 
            requestPath = "/index.html"
          
          var potentialFilename = request.getStaticDir() & "/" & requestPath.replace("..", "")
          if fileExists(potentialFilename):
            debug "Sending " & potentialFilename
            # jester.sendFile(potentialFilename)
            respond system.readFile(potentialFilename)
          else:
            if (request.body == ""):
              raise newException(ReqUnknownException, "404 - File not found")

            # if not a file, assume this is a json request 
            var jsonMessage: JsonNode
            echo request.body
            if (request.body != ""):
              jsonMessage = parseJson(request.body)
            else:
              jsonMessage = parseJson(uri.decodeUrl(requestPath))
            resultId = jsonMessage["responseId"].getInt()
            response = dispatchHttpRequest(jsonMessage, request.headers)
            let jsonResponse = %* { ($jsonMessage["key"]).unescape(): response }
            respond $jsonResponse

        except ReqUnknownException:
          respond Http404, $ %* { "error":"404", "value": getCurrentExceptionMsg(), "resultId": resultId }
        except:
          respond Http500, $ %* { "error":"500", "value":"request doesn't contain valid json", "resultId": resultId } 

  proc copyBackendHelper (folder: string) =
    let targetJs =  folder.parentDir() / "backend-helper.js"
    try:
      when (system.hostOS == "windows"):
        if (not os.fileExists(targetJs) or defined(debug)):
            debug "writing to " & targetJs
            system.writeFile(targetJs, backendHelperJs)
      else:
        if (not os.fileExists(targetJs)):
            debug "symlinking to " & targetJs
            os.createSymlink(system.currentSourcePath.parentDir() / "backend-helper.js", targetJs)
    except:
      logging.error "backend-helper.js not copied" 

  proc startHttpServer*(folder: string, port: int = 8000, bindAddr: string = "localhost") {.exportpy.} =
    var absFolder = folder
    if (not os.isAbsolute(folder)): 
      if (os.getAppFilename().startsWith("python")):
        absFolder = os.getCurrentDir() / folder
      else:
        absFolder = os.getAppDir() / folder
    copyBackendHelper(absFolder)
    var origin = "http://" & bindAddr
    if (bindAddr == "0.0.0.0"):
      origin = "*"
    nimview.responseHttpHeader = { "Access-Control-Allow-Origin": origin }
    let settings = jester.newSettings(port=Port(port), bindAddr=bindAddr, staticDir = absFolder.parentDir())
    var jester = jester.initJester(handleRequest, settings=settings)
    # debug "open default browser"
    # browsers.openDefaultBrowser("http://" & bindAddr & ":" & $port)
    jester.serve()
    
  proc startDesktop*(folder: string, title: string = "nimview", width: int = 640, height: int = 480, resizable: bool = true, debug: bool = defined release) {.exportpy.} =
    when compileWithWebview: 
      var absFolder = folder
      if (not os.isAbsolute(folder)):
        debug os.getAppFilename().extractFilename()
        if (os.getAppFilename().extractFilename().startsWith("python")):
          absFolder = os.getCurrentDir() / folder
        else:
          absFolder = os.getAppDir() / folder
      copyBackendHelper(absFolder)
      os.setCurrentDir(absFolder.parentDir())
      var fullScreen = true
      myWebView = webview.newWebView(title, "file://" / absFolder, width, height, resizable = resizable, debug = debug)
      myWebView.bindProcs("backend"): 
          proc alert(message: string) = webview.info(myWebView, "alert", message)
          proc call(message: string) = 
            info message
            let jsonMessage = json.parseJson(message)
            let resonseId = jsonMessage["responseId"].getInt()
            let response = dispatchJsonRequest(jsonMessage)
            let evalJsCode = "window.ui.applyResponse('" & response.replace("\\", "\\\\").replace("\'", "\\'")  & "'," & $resonseId & ");"
            let responseCode =  webview.eval(myWebView, evalJsCode)
            discard responseCode
  #[          # just sample functions without current real functionality
          proc open() = info myWebView.dialogOpen()
          proc save() = info myWebView.dialogSave()
          proc opendir() = info myWebView.dialogOpen(flag=dFlagDir)
          proc close() = myWebView.terminate()
          proc changeColor() = myWebView.setColor(210,210,210,100)
          proc toggleFullScreen() = fullScreen = not myWebView.setFullscreen(fullScreen) ]#
      myWebView.run()
      myWebView.exit()
      dealloc(myWebView)

  when declared(Thread):
    proc startJesterThread(folder: string) {.thread.} =
      var thread: Thread[string]
      # TODO: potentially re-initialize function map for each thread
      # createThread(thread, startHttpServer, folder, 8000)

  proc start*(folder: string, port: int = 8000, bindAddr: string = "localhost", title: string = "nimview", width: int = 640, height: int = 480, resizable: bool = true) {.exportpy.} =
    let displayAvailable = (os.getEnv("DISPLAY") != "")
    if useJester or not displayAvailable:
      startHttpServer(folder, port, bindAddr)
    else:
      startDesktop(folder, title, width, height, resizable)

proc main() =
  when not defined(noMain):
    debug "starting nim main"
    when system.appType != "lib" and not defined(just_core):
      # startHttpServer(folder)
      nimview.addRequest("appendSomething", proc (value: string): string =
        result = "'" & value & "' modified by Nim Backend")
      
      let argv = os.commandLineParams()
      for arg in argv:
        nimview.readAndParseJsonCmdFile(arg)
      # let folder = os.getCurrentDir() / "tests/vue/dist/index.html"
      let folder = os.getCurrentDir() / "tests/svelte/public/index.html"
      nimview.enableRequestLogger()
      nimview.start(folder)

when isMainModule:
  main()