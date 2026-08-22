local SafelinkU = {}

local cloneReference = cloneref or clonereference or function(instance)
	return instance
end
local HttpService = cloneReference(game:GetService("HttpService"))
local sendRequest = request or http_request or syn_request

function SafelinkU.Create(url, apiToken)
	assert(type(url) == "string" and url ~= "", "SafelinkU requires an original URL")
	assert(type(apiToken) == "string" and apiToken ~= "", "SafelinkU requires an API token")
	assert(type(sendRequest) == "function", "executor does not provide an HTTP request function")

	local response = sendRequest({
		Url = "https://safelinku.com/api/v1/links",
		Method = "POST",
		Headers = {
			Authorization = "Bearer " .. apiToken,
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({ url = url }),
	})

	local statusCode = response and (response.StatusCode or response.Status)
	if statusCode ~= 201 then
		error("SafelinkU returned HTTP " .. tostring(statusCode or "unknown"))
	end

	local decoded = HttpService:JSONDecode(response.Body)
	assert(
		type(decoded) == "table" and type(decoded.url) == "string" and decoded.url ~= "",
		"invalid SafelinkU response"
	)
	return decoded.url
end

return SafelinkU
