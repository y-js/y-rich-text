if(Quill == null){
    alert("You must download quilljs! It needs to be in the same directory as y-richtext!");
}

var quill = new Quill('#editor', {
    modules: {
        'multi-cursor': true,
        'link-tooltip': true,
        'image-tooltip': true
    },
    theme: 'snow'
});
quill.addModule('toolbar', { container: '#toolbar' });
window.connector = new Y.WebRTC('sqfjqsmdlkjrhguemslkfjmlsdkjf',
                                {url: 'http://localhost:8888'});

// connector.debug = true;
window.y = new Y(connector);

checkConsistency = function() {
    deltas = editor.getDelta();
    quill_deltas = quill.getContents().ops;
    for (d in deltas) {
        delta = deltas[d];
        for (name in delta) {
            value = delta[name];
            quill_value = quill_deltas[d][name];
            if (value.constructor === Object) {
                for (n in value) {
                    if (value[n] !== quill_value[n]) {
                        return false;
                    }
                }
            } else if (value !== quill_value) {
                return false;
            }
        }
    }
    return true;
};

checkCursor = function() {
    cursor = editor.selfCursor.getPosition();
    quill_cursor = quill.getSelection().start;
    return cursor === quill_cursor;
}

// quill.on("text-change", function(){
//     if(editor != null && editor.getDelta != null){
//         console.log("Quill & y-richtext are equal: "+checkConsistency())
//     }
// });
// quill.on("selection-change", function() {
//     if (editor != null && editor.selfCursor != null) {
//         console.log("Quill & y-richtext cursor are equal: "+checkCursor());
//     }
// });

function fuzzy_cursor(n) {
    for (var i = 0; i < n; i++) {
        var m = Math.floor(Math.random() * quill.getLength());
        quill.setSelection(m, m);
    }
}
function fuzzy_insert(n) {
    N = 5;
    for (var i = 0; i < n; i++) {
        var m = Math.floor(Math.random() * quill.getLength());
        var j = Math.floor(Math.random() * 2);
        delta = {};
        delta.ops = [{retain: m}];
        var some = Math.min(
            Math.floor(Math.random() * (quill.getLength() - m)) +
                quill.getLength() - m,
            N);
        if (true) {//}j == 0 || quill.getLength() <= N) {
            var randLetter = (Math.random().toString(36) + '00000000000000000')
                    .slice(2, 2 + some);
            delta.ops.push({insert: randLetter});
        }
        else if (j == 1) {
            delta.ops.push({delete: some});
        }
        quill.setContents(delta);
    }
}

function fuzzy_all(n) {
    for (var i = 0; i < n; i++) {
        var which = Math.floor(Math.random() * 2);
        (which === 0) && fuzzy_cursor(1) || fuzzy_insert(1);
    }
}

// TODO: only for debugging
// y._model.HB.stopGarbageCollection();
// y._model.HB.setGarbageCollectTimeout(1500);

y.observe (function (events) {
    for (i in events) {
        if (events[i].name === 'editor') {
            y.val('editor').bind('QuillJs', quill);
            window.editor = y.val('editor');
            window.editor.setAuthor($('#name').val());
        }
    }
});

connector.whenSynced(function(){
    if (y.val('editor') == null) {
        y.val('editor', new Y.RichText('QuillJs', quill));
        y.val('editor').setAuthor($('#name').val());
    }
});



$('#name')
    .click(function() {
        $(this).select();
    })
    .change(function() {
        console.log($(this).val());
        window.editor.setAuthor($(this).val());
    });
