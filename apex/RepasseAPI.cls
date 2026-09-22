@RestResource(urlMapping='/repasse')
global with sharing class RepasseAPI {

    @HttpPost
    global static void doPost() {
        RestResponse res = RestContext.response;
        try {
            String body = RestContext.request.requestBody.toString();
            RepasseRequest payload = (RepasseRequest) JSON.deserialize(
                body, RepasseRequest.class
            );
            payload.validate();

            Id repasseId = new RepasseService().execute(payload);

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new ApiResponse(true, repasseId))
            );
        } catch (ApiException e) {
            res.statusCode = e.statusCode;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new ApiResponse(false, e.getMessage()))
            );
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new ApiResponse(false, e.getMessage() + ' | ' + e.getStackTraceString()))
            );
        }
    }
}