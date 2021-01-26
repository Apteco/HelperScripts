Um Apteco FastStats und PeopleStage als Clients aus dem Browser heraus zu öffnen, können wir eine Session von Orbit wiederbenutzen für den Login. Dafür können sogenannte Bookmarklets verwendet werden. Bookmarks, die kleine Skripte für den aktuell geöffneten Tab ausführen können. Zur Generierung dieses Bookmarklets hilft dieser Generator: https://caiorss.github.io/bookmarklet-maker/

Verwendet wurde dieser Code:

```javascript
var shortcut = "CRMFS";
var orbitUrl = new URL(JSON.parse(window.sessionStorage.config).apiURL);
var url = shortcut + ":"
+ JSON.parse(window.sessionStorage.authenticatedUser).username + "|"
+ "session:" + window.sessionStorage.sessionId + "|"
+ JSON.parse(window.sessionStorage.dataView).name + "|"
+ orbitUrl.protocol + "//" + orbitUrl.host + "/FastStatsWebService/FastStats.asmx";
window.location.href = url;
```

Mit Hilfe des Generators wird dieses Bookmarklet generiert:

```
javascript:(function()%7Bvar%20shortcut%20%3D%20%22CRMFS%22%3B%0Avar%20orbitUrl%20%3D%20new%20URL(JSON.parse(window.sessionStorage.config).apiURL)%3B%0Avar%20url%20%3D%20shortcut%20%2B%20%22%3A%22%0A%2B%20JSON.parse(window.sessionStorage.authenticatedUser).username%20%2B%20%22%7C%22%0A%2B%20%22session%3A%22%20%2B%20window.sessionStorage.sessionId%20%2B%20%22%7C%22%0A%2B%20JSON.parse(window.sessionStorage.dataView).name%20%2B%20%22%7C%22%0A%2B%20orbitUrl.protocol%20%2B%20%22%2F%2F%22%20%2B%20orbitUrl.host%20%2B%20%22%2FFastStatsWebService%2FFastStats.asmx%22%3B%0Awindow.location.href%20%3D%20url%3B%7D)()%3B
```

Dies kann man dann im Browser einfügen:

![grafik](https://user-images.githubusercontent.com/14135678/105817285-af516b00-5fb5-11eb-9183-131b2428cbb3.png)
