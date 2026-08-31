-- Junkie backend adapter for WindUI's key-system provider interface.
local JunkieDevelopment = {}

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local DEFAULT_BACKEND_URL = "https://kocakz-junkie.vercel.app/"

local function getRequestFunction()
	return request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
end

local function getHWID()
	local resolver = gethwid or get_hwid
	if type(resolver) == "function" then
		local ok, value = pcall(resolver)
		if ok and value ~= nil and tostring(value) ~= "" then
			return tostring(value)
		end
	end

	return tostring(Players.LocalPlayer.UserId)
end

local function normalizeURL(value)
	local url = type(value) == "string" and value or DEFAULT_BACKEND_URL
	url = url:match("^%s*(.-)%s*$")
	if url == "" then
		url = DEFAULT_BACKEND_URL
	end
	return url:gsub("/+$", "")
end

local function postJSON(baseURL, path, payload)
	local send = getRequestFunction()
	assert(type(send) == "function", "Your executor does not provide an HTTP request function")

	local response = send({
		Url = baseURL .. path,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
		},
		Body = HttpService:JSONEncode(payload),
	})
	assert(type(response) == "table", "Junkie backend returned no response")

	local status = tonumber(response.StatusCode or response.Status or response.status_code) or 0
	local body = response.Body or response.body
	assert(type(body) == "string" and body ~= "", "Junkie backend returned an empty response")

	local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, body)
	assert(decodeOk and type(decoded) == "table", "Junkie backend returned invalid JSON")
	return decoded, status
end

function JunkieDevelopment.New(backendURL)
	local baseURL = normalizeURL(backendURL)
	local hwid = getHWID()
	local currentSession

	local function validateKey(key)
		if type(key) ~= "string" or key == "" then
			return false, "KEY_INVALID"
		end

		local callOk, result, status = pcall(postJSON, baseURL, "/api/check", {
			key = key,
			hwid = hwid,
		})
		if not callOk then
			return false, "Junkie backend request failed: " .. tostring(result)
		end

		if result.valid == true then
			if type(result.session) ~= "string" or result.session == "" then
				return false, "SESSION_MISSING"
			end
			currentSession = result.session
			return true, tostring(result.message or "KEY_VALID")
		end

		return false, tostring(result.error or result.message or ("HTTP_" .. tostring(status)))
	end

	local function verifySession()
		if type(currentSession) ~= "string" or currentSession == "" then
			return false, "SESSION_MISSING"
		end

		local callOk, result, status = pcall(postJSON, baseURL, "/api/session", {
			session = currentSession,
			hwid = hwid,
		})
		if not callOk then
			return false, "Junkie backend request failed: " .. tostring(result)
		end
		if result.valid == true then
			return true, tostring(result.message or "SESSION_VALID")
		end

		currentSession = nil
		return false, tostring(result.error or result.message or ("HTTP_" .. tostring(status)))
	end

	local function getKeyLink()
		local result, status = postJSON(baseURL, "/api/link", { hwid = hwid })
		if result.success ~= true or type(result.url) ~= "string" or result.url == "" then
			error(tostring(result.error or result.message or ("HTTP_" .. tostring(status))))
		end
		return result.url
	end

	return {
		Verify = validateKey,
		VerifySession = verifySession,
		Copy = getKeyLink,
		SessionOnly = true,
	}
end

return JunkieDevelopment
