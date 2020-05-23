function getController(){
    var url=window.location.href;

    var parts=url.split('.cgi');
    url=parts[0];

    var parts=url.split('/');
    var usecase=parts[parts.length-1];
    return usecase;
}


function set_studio(id){
    var url=window.location.href;
    //split by #
    var comment= url.split(/\#/);
    url=comment.shift();
    comment=comment.join('#');
    //split by ?
    var parts= url.split(/\?/);
    url=parts.shift();
    //split by &
    parts=parts.join('?').split(/\&+/);
    var params=[];
    if (parts.length>0){
        for (index in parts){
            //add all name value pairs but studio id
            var pair=parts[index];
            if(! pair.match(/^studio_id=/)) params.push(pair);
        }
    }
    //add studio id 
    if(id==null)id=-1;
    if(id=='')id=-1;
    params.push('studio_id='+id);
    //append parameters to url
    url+='?'+params.join('&');
    if ((comment!=null)&&(comment!='')) url+='#'+comment;
    window.location.href=url;
}

function set_project(id){
    var url=window.location.href;
    //split by #
    var comment= url.split(/\#/);
    url=comment.shift();
    comment=comment.join('#');
    //split by ?
    var parts= url.split(/\?/);
    url=parts.shift();
    //split by &
    parts=parts.join('?').split(/\&+/);
    var params=[];
    if (parts.length>0){
        for (index in parts){
            //add all name value pairs but project id
            var pair=parts[index];
            if(
                   (! pair.match(/^project_id=/))
                && (! pair.match(/^studio_id=/))
            )params.push(pair);
        }
    }
    //add project id
    if(id==null)id=-1;
    if(id=='')id=-1;
    params.push('project_id='+id);
    //append parameters to url
    url+='?'+params.join('&');
    if ((comment!=null)&&(comment!='')) url+='#'+comment;
    window.location.href=url;
}

function contains(s,t){
    if (s==false) return false;
    if (t==false) return false;
    return s.indexOf(t) != -1; 
}

function updateContainer(id, url, callback){
    //alert(id+":"+url);
    if (id==null) return;
    if ($("#"+id).length==0) return;
    $("#"+id).load(url, callback);
}

function load(url){
    window.location=url;
    //window.location.replace(url);
    //document.location.href=url;
    //$(window).load(url);
    //$('html').load(url);
}


function postContainer(url, parameters, callback){
    if (url!='') $.post(url, parameters, callback);
}

// init getTextWidth
function initTextWidth(){
    if ($('#textWidth').length>0) return;
    $('#content').append('<span id="textWidth" style="padding:0;margin:0;visibility:hidden; white-space:nowrap;"></span>')
}

// get width of selected text
function getTextWidth(s){
    $("#textWidth").html(s);
    return $("#textWidth").width();
}

// check width of all selected elements and set width to max of it
function setTextWidth(select, minValue){
    var maxWidth=minValue;
    $(select).each(
        function(){
            var width=getTextWidth($(this).val())-8;
            if (width>maxWidth) maxWidth=width;
        }
    );
    $(select).each(
        function(){
            $(this).css('width', maxWidth);
        }
    );
}

// trigger action on commit
function commitAction (title, action){
    if (action==null)       {alert("missing action");return}
    if (title==null)        {alert("missing title");return}

    if ($("#dialog-confirm").length>0) $("#dialog-confirm").remove();
    $("#content").append(
        '<div id="dialog-confirm" title="'+title+'" style="min-height:2em;">'
        +'<p>'
        +'<span class="ui-icon ui-icon-alert" style="float:left; margin:0 7px 20px 0;"></span>'
            +'Are you sure?'
        +'</p>'
        +'</div>'
    );

    $( "#dialog-confirm" ).dialog({
        resizable: false,
        height: "200",
        modal: true,
        buttons: {
            Okay : function() {
                $(this).dialog( "close" );
                action();
            },
            Cancel: function() {
                $(this).dialog( "close" );
            }
        }
    });
}

// set action=<action> at form and submit the form after confirmation
function commitForm ( formElement, action, title){
    if (formElement==null)  { alert("missing id");return }
    if (action==null)       { alert("missing action");return }
    if (title==null)        { alert("missing title");return }
    formElement='#'+formElement;
    if ($(formElement).length!=1)    {alert("id "+formElement+" exists not only once, but "+$(formElement).length+" times");return}
    if ($(formElement).is('form')==0) {alert("id "+formElement+" this is not a form");return}
    commitAction(title, 
        function(){
            $(formElement).append('<input type="hidden" name="action" value="'+action+'">');
            $(formElement).submit();
        }
    );
}

function setUrlParameter(url, name, value){
    if(url==null) url=window.location.href;
    //separate url and comments
    var comments=url.split('#');
    url=comments.shift();
    var comment=comments.join('#');

    url=removeUrlParameter(url,name);
    if(!contains(url,'?')) url+='?';
    //add parameter
    url+='&'+name+'='+encodeURIComponent(value);
    url=url.replace('?&','?');
    //add comments
    if ((comments!=null) && (comments!='') )url+='#'+comments;

    return url;    
}

function removeUrlParameter(url, name){
    var r = new RegExp("[\\?]"+name+"=[^&#]*");
    url=url.replace(r,'?');
    var r = new RegExp("&"+name+"=[^&#]*");
    url=url.replace(r,'');
    return url;    
}

function getUrlParameter(name){
    var r = new RegExp("[\\?&]"+name+"=([^&#]*)")
    var results = r.exec( window.location.href );
    if( results == null )return null;
    return results[1];
}

function handleBars(){
    var menu=$('#calcms_nav');
    menu.toggleClass('mobile');
    if (menu.hasClass('mobile')){
        $('#calcms_nav>div').show();
        $('#content').hide();
    }else{
        $('#content').show();
        setupMenu(1);
    }
}

var oldWidth=0;
function setupMenu(update){
    var xmax=960;

    var menu = $('#calcms_nav');
    var width = menu.width();

    if ( (width < xmax)  && (oldWidth >= xmax) ) update=1;
    if ( (width >= xmax) && (oldWidth <  xmax) ) update=1;
    if (oldWidth==0) update=1;

    if (update == 1){
        if (menu.width() < 960){
            $('#calcms_nav>div').hide();
            $('#calcms_nav>div.mobile').show();
        }else{
            $('#calcms_nav>div').show();
            $('#calcms_nav #bars').hide();
            menu.removeClass('mobile');
        }
    }

    oldWidth = width;
}

// will be overridden by calendar.js
function setupMenuHeight(){

    var content=$('#content');
    content.css("position", "relative");

    var menu=$('#calcms_nav');
    var top = menu.height();
    content.css("top", top);

    /*    
    console.log($(window).width()+" "+$(document).width()+" "+$('#content').width());
    var left=0;
    if( $(window).width() >= $(document).width() ){
        left=$(document).width() - $('#content').width();
        left/=2;
        if (left<40)left=0;
    }
    $('#content').css("left", left);    
    */
    return top;
}

function getProjectId(){
    return $('#project_id').val();
}

function getStudioId(){
    return $('#studio_id').val();
}


//set project id and studio id 
function setMissingUrlParameters(){
    console.log("check");
    var project_id=$('#project_id').val();
    var studio_id =$('#studio_id').val();
    if (project_id==null) project_id='';
    if (studio_id==null)  studio_id='';
    if(
           ( project_id != getUrlParameter('project_id') )
        || ( studio_id != getUrlParameter('studio_id') )
    ){
        var project_id=$('#project_id').val();
        var studio_id=$('#studio_id').val();
        var url=window.location.href;
        if(project_id==null){
            console.log("check called too fast");
            return;
        }
        if(studio_id==null){
            console.log("check called too fast");
            return;
        }
        url=setUrlParameter(url, 'project_id', project_id);
        url=setUrlParameter(url, 'studio_id',  studio_id);
        load(url);
    }
}

function checkSession(){
    var datetime=$('#logout').attr('expires');
    if(datetime=='')return;

    var date1=parseDateTime(datetime);
    if(date1==null)return;
    if(date1.getTime()<0)return;

    var intervalID = setInterval(
        function(){
            var now = new Date().getTime();

            var expiry = Math.floor((date1.getTime() - now) / 1000);
            $('#logout').attr('title', "session expires in "+expiry+" seconds");

            if (expiry<120){ 
                alert("session expires soon!");
            }

            if (expiry<0){ 
                alert("session expired!");
                clearInterval(intervalID);
            }
        }, 5000
    );
}

function checkLabel(element){
    var value=element.val();
    console.log(">"+value+"<");
    if (value==''){
        element.parent().find('div.label').hide();
        element.css("padding-top","8px");
    }else{
        element.parent().find('div.label').show();
        element.css("padding-top","0");
    }
}

function initLabels(){
    var selector='div.formField input';
    $(selector).each(function(){
        checkLabel($(this));
        $(selector).keyup(function(){checkLabel($(this));});
    });
};

function copyToClipboard(text){
    if ( text.length == 0 ) return;
    $('body').append('<textarea style="display:none" id="clipboard">' + text + '</textarea>');
    var copyText = document.getElementById('clipboard');
    copyText.select();
    copyText.setSelectionRange(0, 99999);
    document.execCommand("copy");
}

$(document).ready(
    function(){
        setupMenu();
        checkSession();

        setMissingUrlParameters();

        // will be done implicitely on adding back button
        //setupMenuHeight();

        $(window).resize(function() {
            setupMenuHeight();
            setupMenu();
        });

        if(getController()=='calendar'){
            //use build-in localization
            console.log("add back")
            addBackButton();
            return;
        }else{
            //use javascript localization
            setupLocalization(function(){
                addBackButton();
            });
        }
        initLabels();
    }
);


