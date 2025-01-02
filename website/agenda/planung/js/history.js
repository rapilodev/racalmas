function setCookie(name, value) {
    document.cookie = name + "=" + value + "; SameSite=strict;"
}

function clearCookie(name) {
    document.cookie = name + "=; "
}

function getCookie(name) {
    var cookies = document.cookie.split('; ');
    for(var i=0; i<cookies.length; i++) {

        if (cookies[i].indexOf(name+'=')==0){
            return cookies[i].substring(name.length+1);
        }
    }
    return "";
}

function getHistory(){
    var value=getCookie("history");
    var history = value.split("|");
    return history;
}

function comeFromCalendar(){
    var history=getHistory();
    if (history.length<2)return false;
    if (history[1].indexOf("calendar")==-1)return false;
    return true;
}

//return history or null, if url should not be appended to history
function isNewToHistory(url){
    var params=window.location.search;

    var history = getHistory();
    //last page already in history
    if ( history[0] == url) return null;


    //replace url in history by current one, if controller is the same
    var urlController=url.split('.cgi').shift();
    var historyController=history[0].split('.cgi').shift();
    //remove last entry on same controller
    if(urlController==historyController){
        return null;
    }
    return history;
}

// for back button add url to history, if no POST and not visited before
function appendHistory(url, rewrite){
    if (url==null) url=window.location.href;
    //no parameters -> propably POST?

    var history=isNewToHistory(url);
    if (history==null) return;

    //remove first element
    if(rewrite!=null)history.shift();

    //limit size
    if(history.length>20) history.pop();

    if(history.length==0){
        setCookie("history", url);
    }else{
        var content=url;
        var i=0;
        for (i in history){
            if ((history[i]!=null)&& (history[i]!=''))content+='|'+history[i];
        }
        setCookie("history", content);
    }
    //showHistory();
}

function debugShowHistory(){
    var history=getHistory();
    var s='<pre style="z-index:110;position:absolute;right:0;top:0;padding:0">';
    for (var i=5; i>=0;i--){
        if(history[i]!=null) s+=i+" "+history[i]+"\n";
    }
    s+='</pre>';
    $('#content').prepend(s);
}

function getBack(){
    var history=getHistory();
    if (history.length==0)return;

    //remove current page
    var url=history.shift();
    if (history.length==0)return;

    //remove previous page
    var url=history.shift();
    setCookie("history", history.join("|"));
    window.location.href=url;
}

// add back button if not existing
function addBackButton(){

    var backButton=$('#backButton');
    if(backButton.length>0)return;
    if (loc['button_back']==null)return;

    // add back button if history exists
    var history=getHistory();
    //console.log(history.length);
    if (history.length>1){
        $('#calcms_nav').first().prepend(
            '<div><a id="backButton" href="#" onclick="getBack();">'
            +'<img src="image/bright/back.svg">'
            +'&nbsp'
            +loc['button_back']
            +'</a></div>'
        );
    }
    setupMenuHeight();
    //showHistory();
}

$(document).ready(function(){
    //clearCookie();
    appendHistory();
});

