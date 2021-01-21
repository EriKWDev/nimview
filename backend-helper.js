// This file is supposed to be copied automatically to the UI folder, if it doesn't exists there yet

let ui = {};
let defaultPostTarget = "";
let host = ""; // might cause "cors" errors if defined
ui.responseStorage = {};
ui.responseCounter = 0;
/***
 * Generalized request pre-processing
 * Creates a standartized json object to be sent to server and also stores an internal object to handle the response
 * 
 *  request: will be sent to server as json ".request"
 *  callbackFunction: is also optional and required if there is no automated Vue action when changing an object
 *  key: is optional and may be used to re-map the server value; 
 *  inputValue: is optional and may be used set the inputvalue manually instead of using data[key] 
 ***/
ui.createRequest = function(request, data, key, callbackFunction, inputValue) {
  if (typeof inputValue === 'undefined') {
    inputValue = "";
    if ((typeof data === 'object') && (typeof key !== 'undefined') && (key !== '')) {
      if (key in data) {
        inputValue = data[key];
      }
      else {
        // problem - no value in obj - value will be empty string instead of undefined
        if (console && console.log) {
          console.log("Key '" + key + "' not found in data of request:'" + request + "'")
        }
      }
    }
    else {
      inputValue = data;
    }
  }
  if ((typeof key === 'undefined') || (key === "")) {
    key = request;
  }
  if (ui.responseCounter >= Number.MAX_SAFE_INTEGER-1) {
    ui.responseCounter = 0;
  }
  var storageIndex = ui.responseCounter++;
  ui.responseStorage[storageIndex] = new Object({'request': request, 'responseId': storageIndex, 'key': key, 'outputValueObj': data, 
                                                 'callbackFunction': callbackFunction}); // outputValueObj is stored as reference to apply modifications
  var jsonRequest = {'request': request, 'value': inputValue, 'responseId': storageIndex, 'key': key};
  return jsonRequest;
};

/***
 * Generalized request post-processing
 * Maps the previous requestId to an object and applies the (async) response to this object
 ***/
ui.applyResponse = function(value, responseId) {
  var storedObject = ui.responseStorage[responseId];
  if (typeof storedObject.callbackFunction === 'function') {
    storedObject.callbackFunction(value);
  }
  if (storedObject.key && (typeof storedObject.outputValueObj === 'object') && (storedObject.key in storedObject.outputValueObj)) {
    storedObject.outputValueObj[storedObject.key] = value;
  }
  else {
    if (console && console.log) {
      console.log('error in response: ' + JSON.stringify(value) + ' of ' + JSON.stringify(storedObject));
    }
  }
  delete ui.responseStorage[responseId];
};


/*global backend*/
ui.alert = function (str) {
  if (typeof backend === 'undefined') {
    alert(str);
  }
  else {
    backend.alert(str)
  }
}
ui.backend = function (request, data, key, callbackFunction, inputValue) {
  if (typeof backend === 'undefined') {
  // Simulate running in Webview, but using a HTTP server
  // It will not be possible to use MS Edge for debugging, as this has similar identifiers as Webview on Windows 
  // query server with HTTP instead of calling webview callback
    var jsonRequest = ui.createRequest(request, data, key, callbackFunction, inputValue);
    var stringRequest = JSON.stringify(jsonRequest);

    var opts = {
      method: 'POST',      
      mode: 'cors',
      cache: 'no-cache',
      headers: {'Content-Type': 'application/json'},
      body: stringRequest
    };
    if (defaultPostTarget == "") {
      var url = request; // Not required. Just for easier debugging
    }
    else {
      var url = defaultPostTarget; 
    }
    fetch(host + "/" + url, opts).then(function(response) { 
      return response.json();
    }).then(function(response) {
      var key = jsonRequest.key;
      if ((typeof response === "object") && (key in response)) {
        ui.applyResponse(response[key], jsonRequest.responseId);
      }
      else {
        ui.applyResponse(response, jsonRequest.responseId);
      }
    })
    .catch(function(err) {
      console.log(err);
    });
  }
  else {
    // This function is intendend to interact directly with webview. No HTTP server involved.
    // There will be an async call on the backend server, which is then triggering to call javascript from webview.
    // This callback function will be stored in a container ui.responseStorage. Nim Webview had issues calling javascript on Windows
    // at the time of development and therefore required an async approach.
      var jsonRequest = ui.createRequest(request, data, key, callbackFunction, inputValue);
      var stringRequest = JSON.stringify(jsonRequest);
      backend.call(stringRequest);
    }
    ui.alert = function (str) {
      backend.alert(str)
    }
  }

// "import from" doesn't seem to work with webview here... So add this as global variable
window.ui = ui;