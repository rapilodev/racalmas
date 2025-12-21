if (window.page_leave_js) throw "stop"; window.namespace_page_leave_js = true;
"use strict";

var pageHasChangedCounter=0;
var pageIsLoaded=0;

function pageHasChanged(){
    console.log("pageHasChanged="+pageHasChangedCounter)
    if (pageIsLoaded==0) return;
    pageHasChangedCounter++;
    console.log("pageHasChanged="+pageHasChangedCounter);
    return 1;
}

function confirmPageLeave(){
     if(pageHasChangedCounter==0) return null;
     return "Unsaved changed! Continue?";
}

function pageLeaveHandler(){
    $('div.editor input'   ).change(function(){pageHasChanged()});
    $('div.editor textarea').change(function(){pageHasChanged()});
    $('div.editor select'  ).change(function(){pageHasChanged()});

    window.onbeforeunload = function() {
        return confirmPageLeave();
    };

    pageIsLoaded=1;
    console.log("pageLeaveHandler=initialized")

}

function leavePage(){
    pageHasChangedCounter=0;
    console.log("leavePage")
    return 1;
}
