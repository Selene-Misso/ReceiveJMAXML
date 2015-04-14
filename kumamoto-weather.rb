require 'websocket-client-simple'
require 'rexml/document'
require 'time'
require 'nkf'
require 'net/http'
require 'uri'
require 'json'

ws = WebSocket::Client::Simple.connect 'ws://cloud1.aitc.jp:443/websocket/WSServlet'

# Slackとの通信
endpoint = URI.parse('https://hooks.slack.com/services/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')

ws.on :message do |msg|
	doc = REXML::Document.new(msg.data)

	title  = doc.elements['Report/Control/Title'].text
	headtitle = doc.elements['Report/Head/Title'].text
	headline  = doc.elements['Report/Head/Headline/Text'].text
	lines  = doc.elements['Report/Control/EditorialOffice'].text + " "
	time   = Time.parse(doc.elements['Report/Head/ReportDateTime'].text)
	lines += time.strftime("%Y年%m月%d日 %H時%M分%S秒") + " "
	lines += doc.elements['Report/Head/InfoType'].text + "\n"
	lines += "[情報分類] "+doc.elements['Report/Head/InfoKind'].text + "\n"
	lines += "[情報名称] "+title + "\n"
	tmp    = lines

	if doc.elements['Report/Control/EditorialOffice'].text == "熊本地方気象台" then
		if "府県気象情報" == title then
			lines += "[タイトル] #{headtitle} 第" + 
				doc.elements['Report/Head/Serial'].text + "号\n"
			lines += "[見出し] #{headline}\n"
			lines += "[本文] \n"
			desc   = NKF.nkf('-m0Z1 -w', doc.elements['Report/Body/Comment/Text'].text)
			desc.each_line do |line|
				str = ""
				if line.length == 35 then
					str = line.strip
				elsif line.length == 1 then
					str = "\n"
				else
					str = line.strip + "\n"
				end
				lines += str
			end
		elsif "竜巻注意情報" == title then
			lines += "[タイトル] #{headtitle} 第" + 
				doc.elements['Report/Head/Serial'].text + "号\n"
			lines += "[見出し] \n#{headline}\n"
			lines += "[失効時刻] この情報は、"
			time   = Time.parse(doc.elements['Report/Head/ValidDateTime'].text)
			lines += time.strftime("%d日 %H時%M分") + "まで有効です。\n"
		elsif "土砂災害警戒情報" == title then
			lines += "[タイトル] #{headtitle} 第" + 
				doc.elements['Report/Head/Serial'].text + "号\n"
			lines += "[見出し] \n#{headline}\n"
			doc.elements.each('//Information/Item') do |e|
				e.elements.each('Kind/Name') {|ee| lines += ":#{ee.text}: " }
				e.elements.each('Kind/Condition') {|ee| lines += ":#{ee.text}: " }
				e.elements.each('Areas//Name') {|ee| lines += "#{ee.text} "}
				lines += "\n"
			end
		elsif "記録的短時間大雨情報" == title then
			lines += "[タイトル] #{headtitle} 第" + 
				doc.elements['Report/Head/Serial'].text + "号\n"
			lines += "[見出し] #{headline}\n"
		elsif "府県高温注意情報" == title then
			lines += "[タイトル] #{headtitle} 第" + 
				doc.elements['Report/Head/Serial'].text + "号\n"
			lines += "[本文] \n"
			desc   = doc.elements['Report/Body/Comment/Text'].text
			desc.each_line do |line|
				str = ""
				if line.length == 35 then
					str = line.strip
				elsif line.length == 1 then
					str = "\n"
				else
					str = line.strip + "\n"
				end
				lines += str
			end
		elsif "気象特別警報・警報・注意報" == title then
			lines += "[タイトル] #{headtitle}\n"
			lines += "[見出し] #{headline}\n"
			warn   = ""
			prevStatus = ""
			doc.elements.each('//Warning[@type="気象警報・注意報（市町村等）"]/Item') do |e|
				if e.elements['Area//Code'].text == "4310000" then 
					e.elements.each('Area/Name') {|ee| warn += "#{ee.text} "}
					prevStatus = ""
					e.elements.each('Kind') {|ee|
						ee.elements.each('Status') {|eee|
							if prevStatus != eee.text then
								warn += "[#{eee.text}] "
							end
							prevStatus = eee.text
						}
						ee.elements.each('Name')   {|eee| warn += "#{eee.text} " }
					}
					warn += "\n"
				end
			end
			# 熊本市に何もでていなければ内容をクリア
			if prevStatus == "発表警報・注意報はなし" then
				lines = ""
			else
				lines += warn
			end
		end
	end
	if tmp != lines then
		puts lines
		# Slackに通知
		payload = {username: title,text: lines, icon_emoji: ":warning:"}

		https = Net::HTTP.new(endpoint.host, endpoint.port)
		https.use_ssl = true
		req = Net::HTTP::Post.new(endpoint.request_uri)
		req.body = "payload=" + payload.to_json
		res = https.request(req)
	end
end

ws.on :open do
	ws.send 'start'
	ws.send ''
	
	# Heatbeat every 50 sec
	heartbeat = Thread.new do
		loop do
			ws.send ''
			sleep 50
		end
	end
end

ws.on :close do |e|
	p e
	exit 1
end

loop do
	ws.send STDIN.gets.strip
end
