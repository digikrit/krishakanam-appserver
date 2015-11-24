define ['jquery', 'bootstrap', 'requests'], ($, bootstrap, requests) ->
	
	makeRequest = () ->
		withApiUrl (apiUrl) ->
			request = $('#request').val().replace(/^\//, '')
			if isEmpty(request)
				alert 'The Request is required'			
			else
				$('.response-empty, .response').addClass('hidden')
				$('.response-loading').removeClass('hidden')
								
				method = getMethod()
				
				data = {
					url: apiUrl + "/" + request
					method: method
					headers: getHeaders()
					body: if bodyIsRequired(method) then $('#request-body').val() else ''
				}

				console.log "\n-----------------------------\nSent Data:"
				console.log data
				console.log "-----------------------------\n"
								
				crossDomain data,
					(jqXHR) -> showResponse(jqXHR, request, data),
					(jqXHR) -> showResponse(jqXHR, request, data)
													
	showResponse = (jqXHR, request, data) ->
		status = jqXHR.status
		statusText = jqXHR.statusText
		headers = jqXHR.getAllResponseHeaders()
		body = if jqXHR.responseJSON != undefined then JSON.stringify(jqXHR.responseJSON, null, 2) else undefined
		
		withNewLines = (str, newLine) -> str.replace(/[\n\r]+/g, newLine)
		withSpaces = (str) -> str.replace(/\s/g, '&nbsp;')
		
		console.log "\n-----------------------------"
		console.log "Response (jqXHR):"
		console.log jqXHR
		console.log "Status: #{status} #{statusText}"
		console.log "Headers:"
		console.log "\t" + withNewLines(headers, '\n\t')
		console.log "Body:"
		console.log body
		console.log "-----------------------------\n"
		$('#response-status').removeClass('success error').addClass(if status < 400 then 'success' else 'error')
		$('#response-status-code').text(status)
		$('#response-status-text').text(statusText)
		$('#response-headers').html(withNewLines(headers, '<br>'))
		$('#response-body').html(if body != undefined then withSpaces(withNewLines(body, '<br>')) else '')
		$('.response-empty, .response-loading').addClass('hidden')
		$('.response').removeClass('hidden')
		
		switch request
			when 'signin' then storeToken(jqXHR.responseJSON.token); signedIn(JSON.parse(data.body).email)
			when 'signout' then removeToken(); signedOut()
	
	
	setPreparedRequest = (reqName) ->
		{secured, method, uri, body} = requests.prepared(reqName)
		selectMethod(method)
		$('#request').val(if $('#enveloped').prop('checked') then envelope(uri) else uri)
		$('#checkbox-token').prop('checked', secured)
		$('#request-body').val(JSON.stringify(body, null, 2))
	
	
	signIn = () ->
		withApiUrl (apiUrl) ->
			$('#signin').button('loading')
			crossDomain {
					url: apiUrl + "/signin"
					method: 'POST'
					headers: getDefaultHeaders()
					body: JSON.stringify({ email: "akhil", password: "godknows" })
				},
				(jqXHR) -> storeToken(jqXHR.responseJSON.token); signedIn("akhil"),
				(jqXHR) -> console.log jqXHR ; alert('Error while trying to sign in'),
				(jqXHR) -> $('#signin').button('reset')
	
	signOut = () ->
		withApiUrl (apiUrl) ->
			headers = getDefaultHeaders(true)
			tokenHeader = headers['X-Auth-Token']
			if tokenHeader != undefined and tokenHeader.length > 0
				$('#signout').button('loading')
				crossDomain {
						url: apiUrl + "/signout"
						method: 'POST'
						headers: headers
						body: ''
					},
					(jqXHR) -> removeToken(); signedOut(),
					(jqXHR) -> console.log jqXHR ; alert('Error while trying to sign out'),
					(jqXHR) -> $('#signout').button('reset')
			else
				removeToken()

		
#######################################################
# UTILS

	isEmpty = (str) -> not str? or str.length == 0
	
	bodyIsRequired = (method) -> !(method == 'GET' or method == 'DELETE')
	
	selectMethod = (method) ->
		$('#method-selector label[method='+method+']').addClass('active').siblings().removeClass('active')
		if bodyIsRequired(method)
			$('#request-body-section').removeClass('hidden')
		else
			$('#request-body-section').addClass('hidden')
	
	getMethod = () ->
		$('#method-selector label.active').attr('method')
	
	envelopeRequest = (envelopeOrNot) ->
		req = $('#request').val()
		$('#request').val(if envelopeOrNot then envelope(req) else unenvelope(req))
	unenvelope = (req) -> req.replace(/&envelope=[^&]*/ig, '').replace(/[?&]envelope=\w*$/i, '').replace(/\?envelope=\w*&/ig, '?')
	envelope = (req) ->
		unenveloped = unenvelope(req)
		separator = if unenveloped.indexOf('?') == -1 then '?' else '&'
		unenveloped + separator + 'envelope=true'
	
	withApiUrl = (f) ->
		apiUrl = $('#apiurl').val().replace(/\/$/, '')
		if isEmpty(apiUrl)
			alert 'The API URL is required'
		else
			f(apiUrl)
	
	getDefaultHeaders = (withToken = false) ->
		headers = {}
		for tr in $('#request-headers tr')
			[key, value] = [$(tr).find('td.key').text(), $(tr).find('input[type=text]').attr('value')]
			if withToken or key != 'X-Auth-Token'
				headers[key] = value
		headers
	
	getHeaders = () ->
		headers = {}
		for tr in $('#request-headers tr')
			if $(tr).find('input[type=checkbox]').prop('checked')
				[key, value] = [$(tr).find('td.key').text(), $(tr).find('input[type=text]').val()]
				headers[key] = value
		headers
		
	removeKeys = (object, keys) ->
	    filtered = {}
	    for key, value of object
	    	if !(key in keys) then filtered[key] = value
	    filtered
	    
	crossDomain = (data, doneFunc, failFunc, alwaysFunc = (x) -> null) ->
		aElement = document.createElement('a')
		aElement.href = data.url				
		
		# same domain
		if window.location.hostname == aElement.hostname
			headersWithoutDate = removeKeys(data.headers, ["Date"])
			$.ajax {
				url: data.url
				method: data.method
				headers: headersWithoutDate
				data: data.body
			}
			.done (data, textStatus, jqXHR) -> doneFunc(jqXHR) ; alwaysFunc(jqXHR)
			.fail (jqXHR, textStatus, err) -> failFunc(jqXHR) ; alwaysFunc(jqXHR)
		# cross domain
		else
			$.ajax {
				url: '/api/proxy'
				method: 'POST'
				contentType: "application/json"
				data: JSON.stringify(data)
			}
			.done (data, textStatus, jqXHR) -> doneFunc(jqXHR) ; alwaysFunc(jqXHR)
			.fail (jqXHR, textStatus, err) -> failFunc(jqXHR) ; alwaysFunc(jqXHR)
	
	storeToken = (token) ->
		if token? and token.length > 0
			$('#checkbox-token').prop('checked', true)
			$('#token').val(token).attr('value', token)
	removeToken = () ->
		$('#checkbox-token').prop('checked', false)
		$('#token').removeAttr('value')
	
	signedIn = (username) ->
		if username? and username.length > 0
			$('#signin').addClass('hidden')
			$('#signedin').html('Signed in as <b>' + username + '</b>')
			$('#signedin').removeClass('hidden')
			
	signedOut = () ->
		$('#signin').removeClass('hidden')
		$('#signedin').html('')
		$('#signedin').addClass('hidden')
#######################################################
# Document ready

	$ ->
		
		$('#method-selector label[method]').click () -> selectMethod($(this).attr('method'))
		$('#test-button').click () -> makeRequest()
		$('#request').keyup (e) -> if(e.which == 13) then makeRequest()
		$('#test-list a[req]').click () -> setPreparedRequest($(this).attr('req'))		
		$('#signin').click () -> signIn()
		$('#signout').click () -> signOut()
		$('#enveloped').change () -> envelopeRequest($(this).prop('checked'))
		
		$('[data-toggle="tooltip"]').tooltip()