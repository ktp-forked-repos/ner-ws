//var url = "http://156.17.129.135/nerws/ws/";
var url = "http://nlp1.synat.pcss.pl/nerws/";

function processRequest() {
	var pl = new SOAPClientParameters();
	pl.add("input_format", "PLAIN");
	pl.add("output_format", "CCL");
	pl.add("text", document.request_form.request_text.value);
	SOAPClient.invoke(url, "Annotate", pl, true, annotateCallback);
}

function annotateCallback(r) {
	setStatusLine("Processing, please wait...");
	getResult(r.msg);
}

function getResult(token) {
	var pl = new SOAPClientParameters();
	pl.add("token", token);
	SOAPClient.invoke(url, "GetResult", pl, true, getResultCallback(token));
}

function getResultCallback(token) {
	return function(r, soapResponse) {
		if (r instanceof Error)
			setStatusLine('Error: ' + r.message);
		else if (r.status == 3) {
//			alert((new XMLSerializer()).serializeToString(soapResponse));
			setResultText(r.msg);
			setStatusLine("Processing completed.");
		}
		else if (r.status == 4) {
			setStatusLine('Error: ' + r.message);
		}
		else {
			var pl = new SOAPClientParameters();
			pl.add("token", token);
			setTimeout(function() {
				SOAPClient.invoke(url, "GetResult", pl, true, getResultCallback(token)) 
			}, 500);
		}
	}
}

function setStatusLine(text) {
	document.getElementById("status_line").childNodes[0].nodeValue = text;
}

function setResultText(text) {
	var xmlDoc;

	var result_node = document.getElementById("result_text");
	for (var i = 0; i < result_node.childNodes.length; i++) {
		result_node.removeChild(result_node.childNodes[i]);
	}

	if (window.DOMParser) {
		parser = new DOMParser();
		xmlDoc = parser.parseFromString(text, "text/xml");
	}
	// Internet Explorer
	else {
		xmlDoc = new ActiveXObject("Microsoft.XMLDOM");
		xmlDoc.async = "false";
		xmlDoc.loadXML(text);
	}

	var paragraphs = xmlDoc.getElementsByTagName("chunk");
	for (var i = 0; i < paragraphs.length; i++)
		result_node.appendChild(paragraphToDOM(paragraphs[i]));
}

function paragraphToDOM(paragraph) {
	var words = paragraph.getElementsByTagName("tok");
	var result_node = document.createElement("p");
	var current_node = document.createTextNode("");
	result_node.appendChild(current_node);
	var current_annotation = "";
	var current_chan_num = "0";
	var current_ns = false;

	for (var i = 0; i < words.length; i++) {
		var word = words[i];
		var orth = "", annotation = "", chan_num = "";

		// extract token data
		for (var j = 0; j < word.childNodes.length; j++) {
			var node = word.childNodes[j];
			if (node.nodeName == "orth")
				orth = node.childNodes[0].nodeValue;
			else if (node.nodeName == "ann") {
				if (node.childNodes[0].nodeValue != "0") {
					annotation = node.attributes.getNamedItem("chan").value;
					chan_num = node.childNodes[0].nodeValue;
				}
			}
		}

		if ((word.nextSibling.nextSibling) && (word.nextSibling.nextSibling.nodeName == "ns"))
			ns = true;
		else
			ns = false;

		if ((annotation != current_annotation) || (chan_num != current_chan_num)) {
			if (annotation == "") {
				current_node = document.createTextNode("");
				result_node.appendChild(current_node);
				if (!current_ns)
					current_node.nodeValue += " ";
			}
			else {
				if (!current_ns)
					result_node.appendChild(document.createTextNode(" "));
				span = document.createElement("span");
				span.setAttribute("title", annotation);
				font = document.createElement("font");
				font.setAttribute("style", "background-color: yellow");
				current_node = document.createTextNode("");
				font.appendChild(current_node);
				span.appendChild(font);
				result_node.appendChild(span);
			}
		}
		else {
			if (!current_ns)
				current_node.nodeValue += " ";
		}
		
		if (orth == "&quot;")
			orth = "\"";
		current_node.nodeValue += orth;
		current_annotation = annotation;
		current_chan_num = chan_num;
		current_ns = ns;
	}
	
	result_node.appendChild(current_node);
	return result_node;
}

