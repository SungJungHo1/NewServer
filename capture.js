console.log("[*] HTTP 캡처 시작");

Java.perform(function() {
    // Request 캡처
    try {
        var RequestBody = Java.use('okhttp3.RequestBody');
        RequestBody.create.overload('okhttp3.MediaType', 'java.lang.String')
            .implementation = function(mediaType, content) {
                console.log("\n===== REQUEST =====");
                console.log("Type: " + mediaType);
                console.log("Body: " + content);
                console.log("==================\n");
                return this.create(mediaType, content);
            };
    } catch(e) {}
    
    // Response 캡처  
    try {
        var ResponseBody = Java.use('okhttp3.ResponseBody');
        ResponseBody.string.implementation = function() {
            var content = this.string();
            console.log("\n===== RESPONSE =====");
            console.log(content);
            console.log("===================\n");
            return content;
        };
    } catch(e) {}
});