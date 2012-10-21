## HybridAppDemo
A very basic prototype for an HTML5 app using AJAX to call native iOS functions

## Motivation
There are several ways how a HTML5 app inside UIWebView can talk to native code. LinkedIn, for example, uses an embedded 
Objective-C http server and AJAX on the JavaScript side. Since I liked this idea very much I decided to implement a very 
basic prototype myself.

## How it works
The HTML5 client constructs a special JSON object containing the method to call including the parameters and invokes a $.post request against the embedded server.
The class HTTPServer receives the request, parses the JSON and calls the requested function on the Backend class.
The Backend function returns an NSDictionary which gets encoded into JSON and returned back to the client.

## Please note
This is only a prototype! For a proper solution more things need to be done, such as:

* Error handling
* Block requests not coming from the local HTML5 app
* Proper HTTP response headers, like Content-Length
* and so on :)

