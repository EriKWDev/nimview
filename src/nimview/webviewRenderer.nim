# Nimview UI Library 
# © Copyright 2021, by Marco Mengelkoch
# Licensed under MIT License, see License file for more details
# git clone https://github.com/marcomq/nimview


when useWebviewInThread:
    import threadpool
    var webviewQueue: Channel[string]
    var runBarrier: Channel[bool]
    var initBarrier: Channel[bool]
    webviewQueue.open()
    runBarrier.open()
    initBarrier.open()
else:
    {.hint: "Nimview 'callFrontendJs' requires '--threads:on' compiler option to work properly. Webview back-end will block DOM updates otherwise. ".}
when defined webview2:    
    static: 
        echo "Warning: Webview 2 is not stable yet!"
    import nimview/webview2/src/webview except debug
else:
    import nimview/webview/webview except debug

var myWebView*: Webview

proc callFrontendJsEscapedWebview(functionName: string, params: string) =
  ## "params" should be JS escaped values, separated by commas with surrounding quotes for string values
  {.gcsafe.}:
    if not myWebView.isNil:
        let jsExec = "window.ui.callFunction(\"" & functionName & "\"," & params & ");"
        myWebView.dispatch(proc() =
            log.info jsExec
            discard myWebView.eval(jsExec.cstring))

proc selectFolderDialog*(title: string): string  {.exportpy.} =
  ## Will open a "sect folder dialog" if in webview mode and return the selection.
  ## Will return emptys string in webserver mode
  when not defined webview2:
    if not myWebView.isNil():
      result = myWebView.dialogOpen(title=if title != "" : title else: "Select Folder", flag=webview.dFlagDir)
      
proc selectFileDialog*(title: string): string  {.exportpy.} =
  ## Will open a "sect file dialog" if in webview mode and return the selection.
  ## Will return emptys string in webserver mode
  when not defined webview2:
    if not myWebView.isNil():
      result = myWebView.dialogOpen(title=if title != "" : title else: "Select File", flag=webview.dFlagFile)
      
proc evalJs*(evalJsCode: string) =
    myWebView.dispatch(proc() =
        discard myWebView.eval(evalJsCode.cstring))

proc desktopThread(url: string, title: string, width: int, height: int, 
    resizable: bool, debug: bool, run: bool)  =  
    {.gcsafe.}:
        if myWebView.isNil:
            myWebView = webview.newWebView(title, url, width,
                height, resizable = resizable, debug = debug)
        when not defined webview2:
            myWebView.bindProc("nimview", "alert", proc (message: string) =
                myWebView.info("alert", message))
            let dispatchCall = proc (message: string) =
                when useWebviewInThread:
                    webviewQueue.send(message)
                else:
                    computeMessageWebview(message)
            myWebView.bindProc("nimview", "call", dispatchCall)
        else: # webview2
            let dispatchCall = proc (jsonMessage: JsonNode) =
                when useWebviewInThread:
                    webviewQueue.send(message)
                else:
                    nimview.computeMessageWebview($jsonMessag)
            myWebView.bindProc("nimview.call", dispatchCall)
        # nimviewSettings.run = false
        when useWebviewInThread:
            initBarrier.send(true)
            if not run:
                discard runBarrier.recv()
            myWebView.run()
            webviewQueue.send("")
            myWebView.exit()
        else:
            if run:
                myWebView.run()
                myWebView.exit()

proc runWebview*() = 
    when useWebviewInThread:
        runBarrier.send(true)
        while nimviewSettings.run:
            var message = webviewQueue.recv()
            computeMessageWebview(message)
    else:
        myWebView.run()
        myWebView.exit()


proc setBorderless*(decorated: bool = false) {.exportc, exportpy.} =
    ## Use gtk mode without borders, only works on linux and only in desktop mode
    when defined(linux) and compileWithWebview: 
        if not myWebView.isNil():
            {.emit: "gtk_window_set_decorated(GTK_WINDOW(`myWebView`->priv.window), `decorated`);".}

proc setFullscreen*(fullScreen: bool = true) {.exportc, exportpy.} =
    when compileWithWebview and not defined webview2:
        if not myWebView.isNil():
            myWebView.dispatch(proc() = 
                discard myWebView.setFullscreen(fullScreen))


proc setColor*(r, g, b, alpha: uint8) {.exportc, exportpy.} =
    when compileWithWebview and not defined webview2:
        if not myWebView.isNil():
            myWebView.dispatch(proc() = 
                myWebView.setColor(r, g, b, alpha))

proc setMaxSize*(width, height: int) {.exportpy.} =
    when compileWithWebview and not defined webview2:
        if not myWebView.isNil():
            myWebView.dispatch(proc() = 
                myWebView.setMaxSize(width.cint, height.cint))
    
proc setMaxSize*(width, height: cint) {.exportc.} =
    setMaxSize(width, height)

proc setMinSize*(width, height: int) {.exportpy.} =
    when compileWithWebview and not defined webview2:
        if not myWebView.isNil():
            myWebView.dispatch(proc() = 
                myWebView.setMinSize(width.cint, height.cint))
    
proc setMinSize*(width, height: cint) {.exportc.} =
    setMinSize(width, height)

proc focus*(width, height: int) {.exportpy, exportc.} =
    when compileWithWebview and not defined webview2:
        if not myWebView.isNil():
            myWebView.dispatch(proc() = 
                myWebView.focus())