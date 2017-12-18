var loc=new Array;

function addLocalization(usecase, callback){
    $.getJSON( "localization.cgi?usecase="+usecase, function( data ) {
        $.each( data, function( key, val ) {
            loc[key]=val;
        });
                
        if (callback!=null) callback();
        //addBackButton();
    });    
}

function getController(){
    var url=window.location.href;

    var parts=url.split('.cgi');
    url=parts[0];

    var parts=url.split('/');
    var usecase=parts[parts.length-1];
    return usecase;
}

function setupLocalization(callback){
    loc['back']='zurück';

    var usecase=getController();
    addLocalization('all,'+usecase, callback);
}


