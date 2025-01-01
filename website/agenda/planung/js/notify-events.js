function register_buttons() {
    $("#forms form").on('click', 'button', function( event ) {
        event.preventDefault();
        let form = $(this).closest('form');
        let formId = form.attr('id');
        let table = $('#' + formId+" table");
        let  status = table.find("td.result div");
        status.text('').removeClass("error").removeClass("done");

        $.post("notify-events.cgi", form.serialize())
        .always( function(data) {
            if (data.includes("done")){
                status.text("ok").removeClass("error").addClass("done");
            } else {
                status.text(data).removeClass("ok").addClass("error");
            }
            table.find("tr.result").show();
        });
    });
}

function hide_details() {
    $('table.panel tbody').each(function(){
        $(this).children("tr.details").each(function() {
            $(this).hide();
        })
    })

    $('table.panel img.toggle').on("click", function() {
        if( $(this).attr("src").indexOf("arrow-up") < 0 ){
            $(this).attr("src", "image/bright/arrow-up.svg");
        } else {
            $(this).attr("src", "image/bright/arrow-down.svg");
        }
        $(this).closest('tbody').children("tr.details").each(function() {
            $(this).toggle();
        })
    })
}


$(document).ready(function() {
    hide_details();
    register_buttons();
});

