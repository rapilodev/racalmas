var pageHasChangedCounter=0;
var pageIsLoaded=0;

function pageHasChanged(){
    if (pageIsLoaded==0) return;
    pageHasChangedCounter++;
}

function pageLeaveHandler(){
    $('div.editor input'   ).change(function(){pageHasChanged()});
    $('div.editor textarea').change(function(){pageHasChanged()});
    $('div.editor select'  ).change(function(){pageHasChanged()});
 
    window.onbeforeunload = function() {
         if(pageHasChangedCounter==0)return null;
         return "Unsaved changed! Continue?";
    };
    //$(window).unload(function(){});
    pageIsLoaded=1;
}

function leavePage(){
    pageHasChangedCounter=0;
    return 1;
}
