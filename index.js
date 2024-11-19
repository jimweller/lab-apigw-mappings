exports.handler = async (event) => {
    console.log("Received event:", JSON.stringify(event, null, 2));

    // Access the original and transformed parts of the event
    const originalPayload = event.originalCurlPayload;  // Original payload
    const requestTransformPayload = event.requestTransformPayload; // Request transform payload

    // Modify the payload to include the lambda transformation
    const modifiedPayload = {
        originalCurlPayload: originalPayload,  // Original data
        requestTransformPayload: requestTransformPayload,  // Transformed by request template
        lambdaTransformPayload: {  // Lambda's custom transformation
            message: "All pigs are created equal"
        }
    };

    // Return the modified structure (no need to stringify)
    return {
       body: modifiedPayload // Return the object directly
    };
};
