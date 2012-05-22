#import('dart:html');
#import('dart:json');

class ShortnerModel {
  WebSocket _ws;
  get ws() => _ws;
  
  Function onMessage;
  Function onShortUrl;
  Function onError;
  
  void setupWebsocket() {
    _ws = new WebSocket("ws://${window.location.host}/ws");
    _ws.on.open.add((a) {
      print("open $a");
    });
    
    _ws.on.close.add((c) {
      print("close $c");
    });
    
    _ws.on.message.add((message) {
      print("_ws.on.message = ${message}");
      Map data = JSON.parse(message.data);
      if (data.containsKey("surl") && onShortUrl is Function) {
        onShortUrl(data["surl"]);
      }
      
    });
  }
  
  void sendUrl(String url) {
    print(" _ws.send(JSON.stringify({url:$url}));");
    _ws.send(JSON.stringify({"url":url}));
  }
}

class ShortnerView {
  ShortnerController _shortnerController;
  InputElement _urlInput;
  ButtonElement _go;
  DivElement _surl; 
  
  
  ShortnerView() {
    
  }
  
  void setupControls() {
    _urlInput = document.query('#urlInput');
    _go = document.query('#go');
    _surl = document.query('#surl');
    _go.on.click.add((event) {
      
      if (_shortnerController != null) {
        _shortnerController.requestShortUrl(_urlInput.value);
      }
    });
  }
  
  void displayShortUrl(String surl) {
    _surl.innerHTML = "<a id='surl' href=${surl} class='rounded' target='_blank'>$surl</a>";
  }
  
  void addController(controller) {
    _shortnerController = controller;
  }
}

class ShortnerController {
  ShortnerView _shortnerView;
  ShortnerModel _shortnerModel;
  
  ShortnerController(this._shortnerModel, this._shortnerView) {
    
    _shortnerView.addController(this);
    
    _shortnerModel.onShortUrl = _displayShortUrl;
    
    _shortnerModel.setupWebsocket();
    _shortnerView.setupControls();
  }
  
  void _displayShortUrl(String surl) {
    _shortnerView.displayShortUrl(surl);
  }
  
  void requestShortUrl(String u) {
    _shortnerModel.sendUrl(u);
  }
}

void main() {  
  ShortnerView _shortnerView = new ShortnerView();
  ShortnerModel _shortnerModel = new ShortnerModel();
  ShortnerController _shortnerController = new ShortnerController(_shortnerModel, _shortnerView);
}
