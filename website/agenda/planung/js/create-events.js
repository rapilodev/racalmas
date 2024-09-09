async function create_events(form_id){
    let form = $("#"+form_id);
    let json = postJson("create-events.cgi?", {
        action: "create_events",
        project_id: form.find("input[name='project_id']").val(),
        studio_id: form.find("input[name='studio_id']").val(),
        series_id: form.find("input[name='series_id']").val(),
        duration: form.find("select[name='duration'] option").filter(':selected').val(),
    });
    if(json.created == 0) showWarn('no events found in selected timespan');
    else showInfo(`${json.created} events created`);
    show_events('create_event_form');
}

async function show_events(form_id){
    let target = $('#events tbody');
    target.html();
    let form = $("#" + form_id);

    var doc = await getJson("create-events.cgi?", {
        action: "get_events",
        project_id: getProjectId(),
        studio_id: getStudioId(),
        series_id: form.find("input[name='series_id']").val(),
        duration: form.find("select[name='duration'] option").filter(':selected').val(),
    });
    $('#stats').html(doc.events.length + " events found from " +  fmtDate(doc.from) + " till " + fmtDate(doc.till));
    console.log(form.find("button[name='action']"));
    if (doc.events.length ==0){
        $('#events').hide();
        form.find("button[name='action']").attr("disabled", true);
    } else {
        $('#events').show();
        form.find("button[name='action']").removeAttr("disabled");
    }

    var out = '';
    for (const entry of doc.events) {
        out += `<tr>
        <td>${fmtDatetime(entry.start)}</td>
        <td>${fmtDatetime(entry.end)}</td>
        <td>${entry.series_name} - ${entry.series_title || ''}</td>
        </tr>`;
    }
    target.html(out);
}

function selectChangeSeries(resultSelector){
    var url='select-series.cgi?' + new URLSearchParams({
        project_id : getProjectId(),
        studio_id : getStudioId(),
        series_id : getUrlParameter('series_id'),
        resultElemId: resultSelector,
        selectSeries: 1,
    }).toString();
    updateContainer('seriesContainer', url, function() {
        $('#selectSeries').removeClass('panel');
        var series_id = $('input[name=series_id]').val();
        if (series_id.length) $("option[value='"+series_id+"']").attr('selected','selected');
        $('#create_event_form select').on('change', () => show_events('create_event_form'));
    });
}

function init(){
    selectChangeSeries('select_series_id');
    show_events('create_event_form');
}

$(document).ready(function() {
    init();
});
