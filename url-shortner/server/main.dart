#import('dart:io');
#import('dart:json');
#import('dart:uri');

#import('../../mongo-dart/lib/mongo.dart');

final IP = '127.0.0.1';
final PORT = 8080;
final ROOT_URL = "http://127.0.0.1:8080/r/";

String shortener(seq) {
  var chars = "abcdefghijklmnopqrstuvxzwyABCDEFGHIJKLMNOPQRSTUVXZWY1234567890";
  StringBuffer sb = new StringBuffer();
  while (seq > 0){
      var k = seq % chars.length;
      if (k == 0) { 
        k = 62; 
        seq--; 
      }
      seq = (seq / chars.length).floor().toInt(); 
      sb.add(chars[k-1]);
  }
  return sb.toString();
}


class LinkShortner {
  LinkShortner() {
    
  }
  
  
  Future<String> addLink(urltosort) {
    Db db = new Db('LinkShortner');
    DbCollection collection;
    Map url;
    
    Completer completer = new Completer();
    
    // Open connection to db.
    db.open().chain((_) {
      // open the urls collection
      collection = db.collection("urls");
      print('collection.findOne({"url":urltosort});');
      return collection.findOne({"url":urltosort});
    }).chain((storedUrl) {
      // If a stored url is found set the Map url
      if (storedUrl != null) {
        url = storedUrl; // return the url if found.
      } else {
        // increment the url count to insert a new url.
        collection.update({"_id":"urlCount"}, {"\$inc": {"count":1}});
      }
      
      print('collection.findOne({"_id":"urlCount"});');
      return collection.findOne({"_id":"urlCount"});
    }).chain((urlCount) {
      // if null create 
      if (urlCount == null) {
        collection.insert({"_id":"urlCount", "count": 1});
      } 
      
      print('collection.findOne({"_id":"urlCount"});');
      return collection.findOne({"_id":"urlCount"});
    }).chain((u) {
      // If the url was not found in the db, then add it
      if (url == null) {
        url = {  "url":urltosort,
                 "surl":"${ROOT_URL}${shortener(u["count"])}",
                 "shorten_count":0,
                 "access_count":0
        };
        print("collection.insert(url);");
        //return collection.insert(url);
        collection.insert(url);
      } //else {
        print("collection.findOne({'url':urltosort});");
        return collection.findOne({"url":urltosort});
      //}      
    }).then((su) {
      collection.update(su, {"\$inc": {"shorten_count":1}});
      completer.complete(su["surl"]);
      db.close();
      print("db.close();");
    });
    
    
    return completer.future;
    
  }
  
  Future findShortLinkRedirect(link) {
    Completer completer = new Completer();
    Db db = new Db('LinkShortner');
    DbCollection collection;
    
    db.open().chain((_) {
      collection = db.collection("urls");
      return collection.findOne({"surl": '${ROOT_URL}${link}'});
    }).then((u) {
      collection.update(u, {"\$inc": {"access_count":1}});
      completer.complete(u["url"]);
      db.close();
    });
    
    return completer.future;
  }
}

redirectHandler(HttpRequest req, HttpResponse res) {
  
}

void main() {
  LinkShortner linkShortner = new LinkShortner();
  HttpServer server = new HttpServer();
  WebSocketHandler wsHandler = new WebSocketHandler();
  
  // Websocket handler
  server.addRequestHandler((req) => req.path == "/ws", wsHandler.onRequest);
  
  // Redirect handler
  server.addRequestHandler((req) => req.path.startsWith("/r/"), (HttpRequest req, HttpResponse res) {
    linkShortner.findShortLinkRedirect(req.path.substring(3)).then((r) {
      // Send the meta redirect to the client
      String redirect = "<html><meta http-equiv='refresh' content='0;url=${r}'></html>";
      print("redirect = ${redirect}");
      res.outputStream.writeString(redirect);
      res.outputStream.close();
    });
  });
  
  // Static files map
  Map staticFiles = new Map();
  staticFiles["/"] = "../client/shortner/shortner.html";
  staticFiles["/shortner.html"] = "../client/shortner/shortner.html";
  staticFiles["/shortner.dart"] = "../client/shortner/shortner.dart";
  staticFiles["/shortner.dart.js"] = "../client/shortner/shortner.dart.js";

  // Static files handler
  staticFiles.forEach((k,v) {
    server.addRequestHandler((req) => req.path == k, (HttpRequest req, HttpResponse res) {
      try {
        File file = new File(v); 
        file.openInputStream().pipe(res.outputStream); 
      } catch (var ex) {
        print("ex = ${ex}");
      }
    });
  });
  
  wsHandler.onOpen = (WebSocketConnection conn) {
    print("wsHandler.onOpen");
    
    conn.onMessage = (message) {
      var jsonMessage = JSON.parse(message);
      var d = jsonMessage["url"];
      
      // TODO: need a way to validate the url format
      Uri u = new Uri.fromString(d);
      if (!(u.scheme.startsWith("http") || 
          u.scheme.startsWith("https") ||
          u.scheme.startsWith("ftp"))) {
        print("u = ${u.toString()}");
        print("u.scheme = ${u.scheme.toString()}");
        u = new Uri.fromString("http://$d");
      }
            
      linkShortner.addLink(u.toString()).then((c) {
        var r = JSON.stringify({"surl":c});
        conn.send(r);
      });
      
    };
    
    conn.onClosed =  (int status, String reason) {
      print("conn.onClosed status=${status},reason=${reason}");
    };
    
    conn.onError = (e) {
      print("conn.onError e=${e}");
    };
  };
  
  print('listing on http://$IP:$PORT');
  server.listen(IP, PORT);
}
