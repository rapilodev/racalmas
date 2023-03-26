function selectChangeSeries(resultSelector){
    var url='select-series.cgi?' + new URLSearchParams({
        project_id : getProjectId(),
        studio_id : getStudioId(),
        series_id : getUrlParameter('series_id'),
        resultElemId: resultSelector,
        selectSeries: 1,
    }).toString();
    updateContainer('seriesContainer', url, function(){
        $('#selectSeries').removeClass('panel');
        var series_id = $('input[name=series_id]').val();
        if (series_id.length) $("option[value='"+series_id+"']").attr('selected','selected');
    });
}

$(document).ready(function() {
    selectChangeSeries('select_series_id');
});
