"use strict";

function getParent() {
    return document.querySelector("body > center > #content");
}

function closeImageManager() {
    getParent().style.display = 'block';
    $('#image-manager').hide(1000).remove();
}

var commitImageHandler;
var target;

// open image editor, pid used for projects
async function selectImage(image, callback) {
    commitImageHandler = callback;
    target = image.target;
    
    let project_id = image.project_id;
    let studio_id = image.studio_id;

    getParent().style.display = "none";
    $('body').append($('<div id="image-manager">'));
    $("#image-manager").on("click", "#abort-image-editor", closeImageManager);

    $("#image-manager").on("click", "#search-button",
        () => searchImage(project_id, studio_id, $("input#search-field").val())
    );

    let [manager, file_images, series_images, search_images] = await Promise.all([
        updateContainer('image-manager', 'image.cgi?' + new URLSearchParams({
            "action": 'show',
            "project_id": project_id,
            "studio_id": studio_id
        }).toString()),

        image.filename ? getJson('image.cgi', {
            "action": 'get',
            "project_id": project_id,
            "studio_id": studio_id,
            "filename": image.filename
        }) : Promise.resolve([]),
        image.series_id ? getJson('image.cgi', {
            "action": 'get',
            "project_id": project_id,
            "studio_id": studio_id,
            "series_id": image.series_id
        }) : Promise.resolve([]),

        image.search ? getJson('image.cgi', {
            "action": 'get',
            "project_id": project_id,
            "studio_id": studio_id,
            "search": image.search
        }) : Promise.resolve([])
    ]);

    let images = Array.from(new Map([
        ...file_images.images.map(img => [img.filename, img]),
        ...series_images.images.map(img => [img.filename, img]),
        ...search_images.images.map(img => [img.filename, img]),
    ]).values());
    listImages(project_id, studio_id, images);
    return false;
}

function listImages(project_id, studio_id, images) {

    let container = document.querySelector("#image-manager div.images");
    container.innerHTML = '';;
    console.log("container", container)
    if (!container) throw new Error("nos container");

    for (let image of images) {
        let div = document.createElement("div");
        for (let [key, value] of Object.entries(image)) {
            div.dataset[key] = value;
        }
        div.className = "image";
        div.id = `img_${image.id}`;
        div.title = image.description || "";
        let url = `show-image.cgi?` + new URLSearchParams({
            project_id: image.project_id,
            studio_id: image.studio_id,
            type: "icon",
            filename: image.filename
        }).toString();
        div.style.backgroundImage = `url('${url}')`;
        div.addEventListener('click', function() {
            loadImageEditor(project_id, studio_id, div.dataset.filename);
        });
        container.append(div);
    }

    setActiveImage(document.querySelector("div.images div.image"));
    console.log("images initialized")

    return;
}

function setActiveImage(elem) {
    document.querySelectorAll("div.image").forEach(image => {
        image.classList.remove("active");
        image.classList.add("inactive");
    });
    if (!elem) return;
    elem.classList.add("active");
    elem.classList.remove("inactive");
    updateActiveImage();
}

function updateActiveImage() {
    $('div.images div.image.active').click();
}

function parseImageForm() {
    let image = {};
    let editor = document.querySelector("#imageEditor");
    image.name = editor.querySelector("#name").value;
    image.description = editor.querySelector("#description").value;
    image.license = editor.querySelector("#license").value;
    image.project_id = editor.querySelector("#project_id").value;
    image.studio_id = editor.querySelector("#studio_id").value;
    image.public = editor.querySelector("#public").value;
    console.log(image)
    return image;
}

function setImageForm(image){
    let editor = document.querySelector("#imageEditor");
    editor.querySelector("#name").value = image.name || '';
    editor.querySelector("#description").value = image.description || '';
    editor.querySelector("#license").value = image.license || '';
    editor.querySelector("#public").checked = !!image.public;
    editor.querySelector("#project_id").value = image.project_id || 0;
    editor.querySelector("#studio_id").value = image.studio_id || 0;
}

// show or edit image properties
async function loadImageEditor(project_id, studio_id, filename) {
    var loc = getLocalization();
    let editor = document.querySelector("#imageEditor");
    let json = await getJson('image.cgi', {
        "action": 'get',
        "project_id": project_id,
        "studio_id": studio_id,
        "filename": filename
    });
    console.log(json)
    let image = json.images[0];

    setImageForm(image);

    document.querySelector('#image_properties').innerHTML = `
    ${loc.label_created_at} ${image.created_at} ${loc.label_created_by} ${image.created_by}<br>
    ${loc.label_modified_at} ${image.modified_at} ${loc.label_modified_by} ${image.modified_by}<br>
    ${loc.label_link} {{${image.filename}|${image.name}}}<br>
    `;

    let tools = editor.querySelector("#tools");
    tools.innerHTML = '';
    if (image.public) {
        tools.appendChild(button({
            id: "assignButton",
            text: loc["label_assign_to_" + target],
            onClick: () => commitImageHandler()
        }));
        tools.appendChild(button({
            id: "depublishButton",
            text: loc.button_depublish,
            onClick: () => depublishImage()
        }));
    } else {
        tools.appendChild(element("div", {
            className: "warn",
            textContent: loc['label_warn_not_public_' + target]
        }));

        if (image.license) {
            tools.appendChild(button({
                id: "publishButton",
                text: loc.button_publish,
                onClick: () => publishImage()
            }));
        } else {
            tools.appendChild(element("div", {
                className: "warn",
                textContent: loc.label_warn_unknown_licence
            }));
        }
    }
    
    editor.querySelector("#save-image").addEventListener("click", () => saveImage(parseImageForm()));
    editor.querySelector("#delete-image").addEventListener("click", () => askDeleteImage(parseImageForm().filename));
}

async function searchImage(project_id, studio_id, search) {
    let params = new URLSearchParams({
        action: "get",
        project_id,
        studio_id,
        search
    });
    console.log(search, params);
    let json = await getJson('image.cgi', params);
    listImages(project_id, studio_id, json.images);
    return false;
}

function saveImage(image) {
    image.action = "save";
    return postJson('image.cgi?', image);
}

function depublishImage() {
    image = parseImageForm();
    image.public = 0;
    saveImage(image);
}

function publishImage() {
    image = parseImageForm();
    image.public = 1;
    saveImage(image);
    loadImageEditor(image.project_id, image.studio_id, image.filename)
}

function askDeleteImage(filename) {
    commitAction("delete image", () => deleteImage(filename));
}

async function deleteImage(filename) {
    var json = await getJson('image.cgi', {
        "action": "delete",
        "project_id": getProjectId(),
        "studio_id": getStudioId(),
        "filename": filename,
    });
    return false;
}

function uploadImage() {
    var form = $("#img_upload");
    var fd = new FormData(form[0]);
    var rq = $.ajax({
        url: 'image-upload.cgi',
        type: 'POST',
        data: fd,
        cache: false,
        contentType: false,
        processData: false
    });

    rq.done(function(data) {
        var image_id = $("#upload_image_id").html();
        var filename = $("#upload_image_filename").html();
        var title = $("#upload_image_title").html();
        //remove existing image from list
        $('#imageList div.images #img_' + image_id).remove();
        var url = icon(getProjectId(), getStudioId(), filename).src;

        var html = '<div';
        html += ' id="img_' + image_id + '"';
        html += ' class="image" ';
        html += ' title="' + title + '" ';
        html += ' style="background-image:url(' + url + ')"';
        html += ' filename="' + filename + '"';
        html += '>';
        html += '    <div class="label">' + title + '</div>';
        html += '</div>';

        //add image to list
        $('#imageList div.images').prepend(html);
        return false;
    });

    rq.fail(function() {
        console.log("Fail")
    });

    return false;
};

$(document).ready(function() {
    function updateCheckBox(selector, value) {
        $(selector).attr('value', value)
        $(selector).prop("checked", value == 1);
    }

    loadLocalization('image');
    var checkbox = $("#img_editor input[name='public']");
    updateCheckBox(checkbox);
    checkbox.change(() => updateCheckBox(checkbox));
    console.log("image handler initialized");
});

