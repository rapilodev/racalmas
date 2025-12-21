if (window.namespace_comment_js) throw "stop"; window.namespace_comment_js = true;
"use strict";

function showCommentsByAge(age){
    var url='comment.cgi?';
    url += '&action=show';
    url += '&project_id='+getProjectId();
    url += '&studio_id='+getStudioId();
    url += '&age='+age;
    window.location.href=url;
}

function showEventComments(eventId){
    var elemId="event_"+eventId+"_comments";
    var element=$("#"+elemId);

    if (element.css('display')=='none'){
        loadComments(eventId, function(){
            scrollToComment(eventId);
        });
    }else{
        hideComments(elemId);
    }
    return false;
}

function loadComments(eventId, callback){
    var url='comment.cgi?';
    url += '&action=show';
    url += '&project_id='+getProjectId();
    url += '&studio_id='+getStudioId();
    url += '&event_id='+eventId;
    //console.log(url);
    var elemId="event_"+eventId+"_comments";
    var element=$("#"+elemId);

    element.load(
        url,
        function(){
            showComments(elemId);

            if(callback!=null){
                //console.log("callback");
                callback();
            }
        }
    );
}

function showComments(elemId){
    var element=$("#"+elemId);
    if(element.is("tr")){
        element.css("display","table-row");
        return;
    }else{
        element.slideDown();
    }
}

function hideComments(elemId){
    //console.log("hide comments for "+elemId);

    var element=$("#"+elemId);
    if(element.is("tr")){
        element.css("display","none");
        element.empty();
        return;
    }else{
        element.slideUp("normal",function(){
            element.empty();
        });
    }
}

function scrollToComment(eventId){
    $('html, body').animate({
        scrollTop: $("#event_"+eventId+"_comments").offset().top - 100
        }, 2000
    );
}

function setCommentStatusRead(commentId, eventId, status){
    var url='comment.cgi?'
    url += '&action=setRead';
    url += '&readStatus='+status;
    url += '&project_id='+getProjectId();
    url += '&studio_id='+getStudioId();
    url += '&event_id='+eventId;
    url += '&comment_id='+commentId;
    //console.log(url);
    $("#event_"+eventId+"_comments").load(
        url,
        function(){
            loadComments(
                eventId,
                function(){
                    scrollToComment(eventId);
                }
            );
        }
    );
    return false;
}

function setCommentStatusLock(commentId,eventId,status){
    var url='comment.cgi?'
    url += '&action=setLock';
    url += '&lockStatus='+status;
    url += '&project_id='+getProjectId();
    url += '&studio_id='+getStudioId();
    url += '&event_id='+eventId;
    url += '&comment_id='+commentId;
    //console.log(url);

    $("#event_"+eventId+"_comments").load(
        url,
        function(){
            loadComments(
                eventId,
                function(){
                    scrollToComment(eventId);
                }
            );
        }
    );
    return false;
}

