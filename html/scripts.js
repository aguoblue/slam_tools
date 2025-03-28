document.getElementById('helloButton').addEventListener('click', function() {
    fetch('http://127.0.0.1:5000/hello', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('responseMessage').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('responseMessage').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('egoButton').addEventListener('click', function() {
    fetch('http://127.0.0.1:5000/ego', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('egoResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('egoResponse').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('rtabButton').addEventListener('click', function() {
    fetch('http://127.0.0.1:5000/rtab', {
        method: 'POST',
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('rtabResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('rtabResponse').innerText = "请求失败";
    });
    refreshIframe();
});

document.getElementById('setPointButton').addEventListener('click', function() {
    const x = document.getElementById('x-coord').value;
    const y = document.getElementById('y-coord').value;
    const z = document.getElementById('z-coord').value;
    
    fetch('http://127.0.0.1:5000/set_target', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            x: parseFloat(x),
            y: parseFloat(y),
            z: parseFloat(z)
        })
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('egoResponse').innerText = data.message;
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('egoResponse').innerText = "设置目标点失败";
    });
});

function switchContent(pageId) {
    document.querySelectorAll('.content-page').forEach(page => {
        page.style.display = 'none';
    });
    
    document.getElementById(pageId).style.display = 'block';
    
    document.querySelectorAll('.nav-button').forEach(button => {
        button.classList.remove('active');
    });
    document.querySelector(`[onclick="switchContent('${pageId}')"]`).classList.add('active');
}

function refreshIframe() {
    const frame = document.getElementById('foxgloveFrame');
    frame.src = frame.src;
}
