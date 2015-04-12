require 'websocket-client-simple'
require 'rexml/document'
require 'time'
require 'nkf'

ws = WebSocket::Client::Simple.connect 'ws://cloud1.aitc.jp:443/websocket/WSServlet'

ws.on :message do |msg|
	doc = REXML::Document.new(msg.data)

	title  = doc.elements['Report/Control/Title'].text
	headtitle = doc.elements['Report/Head/Title'].text
	headline  = doc.elements['Report/Head/Headline/Text'].text
	lines  = doc.elements['Report/Control/EditorialOffice'].text + " "
	time   = Time.parse(doc.elements['Report/Head/ReportDateTime'].text)
	lines += time.strftime("%Y年%m月%d日 %H時%M分%S秒") + " "
	lines += doc.elements['Report/Head/InfoType'].text + "\n"
	lines += ":情報分類: "+doc.elements['Report/Head/InfoKind'].text + "\n"
	lines += ":情報名称: "+title + "\n"
	tmp    = lines

	if    "府県天気概況" == title then
		lines += ":タイトル: #{headtitle}\n"
		lines += ":見出し: #{headline}\n"
		lines += ":本文: \n"
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
	#		if /波の高さ/u =~ str then
	#			break
	#		end
			lines += str
		end
	elsif "府県気象情報" == title then
		lines += ":タイトル: #{headtitle} 第" + 
			doc.elements['Report/Head/Serial'].text + "号\n"
		lines += ":見出し: #{headline}\n"
		lines += ":本文: \n"
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
	elsif "竜巻注意情報" == title then
		lines += ":タイトル: #{headtitle} 第" + 
			doc.elements['Report/Head/Serial'].text + "号\n"
		lines += ":見出し: \n#{headline}\n"
		lines += ":失効時刻: この情報は、"
		time   = Time.parse(doc.elements['Report/Head/ValidDateTime'].text)
		lines += time.strftime("%d日 %H時%M分") + "まで有効です。\n"
	elsif "土砂災害警戒情報" == title then
		lines += ":タイトル: #{headtitle} 第" + 
			doc.elements['Report/Head/Serial'].text + "号\n"
		lines += ":見出し: \n#{headline}\n"
		doc.elements.each('//Information/Item') do |e|
			e.elements.each('Kind/Name') {|ee| lines += ":#{ee.text}: " }
			e.elements.each('Kind/Condition') {|ee| lines += ":#{ee.text}: " }
			e.elements.each('Areas//Name') {|ee| lines += "#{ee.text} "}
			lines += "\n"
		end
	elsif "記録的短時間大雨情報" == title then
		lines += ":タイトル: #{headtitle} 第" + 
			doc.elements['Report/Head/Serial'].text + "号\n"
		lines += ":見出し: #{headline}\n"
	elsif "府県高温注意情報" == title then
		lines += ":タイトル: #{headtitle} 第" + 
			doc.elements['Report/Head/Serial'].text + "号\n"
		lines += ":本文: \n"
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
		lines += ":タイトル: #{headtitle}\n"
		lines += ":見出し: #{headline}\n"
		warn   = ""
		prevStatus = ""
		doc.elements.each('//Warning[@type="気象警報・注意報（市町村等）"]/Item') do |e|
			if e.elements['Area//Code'].text == "4310000" then 
				e.elements.each('Area/Name') {|ee| warn += ":#{ee.text}: "}
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
	elsif "震度速報" == title then
		lines += ":見出し: "
		lines += NKF.nkf('-m0Z1 -w', headline) + "\n"
		lines += ":最大震度: "+doc.elements['//Observation/MaxInt'].text + "\n"
		doc.elements.each('//Information[@type="震度速報"]/Item') do |e|
			e.elements.each('Kind/Name') {|ee|
				lines += ":#{NKF.nkf('-m0Z1 -w', ee.text)}: "
			}
			e.elements.each('Areas/Area/Name') {|ee| lines += "#{ee.text} "}
			lines += "\n"
		end
		lines += ":固定付加文: "+
			doc.elements['//ForecastComment[@codeType="固定付加文"]/Text'].text + "\n"
	elsif "震源に関する情報" == title then
		lines += ":見出し: "
		lines += NKF.nkf('-m0Z1 -w', headline) + "\n"
		lines += ":震源: "+doc.elements['//Hypocenter/Area/Name'].text + " "
		lines += NKF.nkf('-m0Z1 -w',doc.elements['//jmx_eb:Coordinate'].attributes["description"]) + "\n"
		lines += ":規模: "+doc.elements['//jmx_eb:Magnitude'].attributes["type"] + 
			doc.elements['//jmx_eb:Magnitude'].text + "\n"
		lines += ":固定付加文: "+
			doc.elements['//ForecastComment[@codeType="固定付加文"]/Text'].text + "\n"
	elsif "震源・震度に関する情報" == title then
		lines += ":見出し: "
		lines += NKF.nkf('-m0Z1 -w', headline) + "\n"
		lines += ":震源: "+doc.elements['//Hypocenter/Area/Name'].text + " "
		lines += NKF.nkf('-m0Z1 -w',doc.elements['//jmx_eb:Coordinate'].attributes["description"]) + "\n"
		lines += ":規模: "+doc.elements['//jmx_eb:Magnitude'].attributes["type"] + 
			doc.elements['//jmx_eb:Magnitude'].text + "\n"

		lines += ":最大震度: "+doc.elements['//Observation/MaxInt'].text + "\n"
		doc.elements.each('//Information[@type="震源・震度に関する情報（市町村等）"]/Item') do |e|
			e.elements.each('Kind/Name') {|ee|
				lines += ":#{NKF.nkf('-m0Z1 -w', ee.text)}: "
			}
			e.elements.each('Areas/Area/Name') {|ee| lines += "#{ee.text} "}
			lines += "\n"
		end
		lines += ":固定付加文: "+
			doc.elements['//ForecastComment[@codeType="固定付加文"]/Text'].text + "\n"
	elsif "地震の活動状況等に関する情報" == title then
		lines += ":見出し: "
		lines += NKF.nkf('-m0Z1 -w', headline) + "\n"
		lines += ":名称: #{NKF.nkf('-m0Z1 -w',doc.elements['//Body/Naming'].text)}\n" +
			NKF.nkf('-m0Z1 -w',doc.elements['//Body/Naming'].attributes["english"]) + "\n"
		lines += ":本文:\n#{NKF.nkf('-m0Z1 -w',doc.elements['//Body/Text'].text)}\n"
	elsif "津波警報・注意報・予報a" == title then
		lines += ":タイトル: #{headtitle}\n"
		lines += ":見出し:   #{NKF.nkf('-m0Z1 -w',headline)}\n"
		
		doc.elements.each('//Information/Item') do |e|
			e.elements.each('Kind/Name') {|ee| lines += ":#{ee.text}: " }
			e.elements.each('Areas//Name') {|ee| lines += "#{ee.text} "}
			lines += "\n"
		end
		
		lines += ":固定付加文: \n"+
			doc.elements['//WarningComment[@codeType="固定付加文"]/Text'].text + "\n"
		lines += ":震源: "+doc.elements['//Hypocenter/Area/Name'].text + " "
		lines += NKF.nkf('-m0Z1 -w',doc.elements['//jmx_eb:Coordinate'].attributes["description"]) + "\n"
		lines += ":規模: "+NKF.nkf('-m0Z1 -w',doc.elements['//jmx_eb:Magnitude'].attributes["description"]) + "\n"
	elsif "津波情報a" == title then
		lines += ":タイトル: #{headtitle}\n"
		lines += ":見出し:   #{NKF.nkf('-m0Z1 -w',headline)}\n"
		
		doc.elements.each('//Tsunami/Observation/Item') do |e|
			e.elements.each('Area/Name') {|ee| lines += ":#{ee.text}: "}
			e.elements.each('Station') {|ee| 
				ee.elements.each('Name'){|eee| 
					lines += ":#{eee.text}: "
					eee.elements.each('../MaxHeight/jmx_eb:TsunamiHeight'){|m|
						lines += "#{NKF.nkf('-m0Z1 -w',m.attributes['description'])} "
					}
					eee.elements.each('../MaxHeight/Condition'){|m|
						lines += "#{NKF.nkf('-m0Z1 -w',m.text)} "
					}
				}
			}
			lines += "\n"
		end
		
		lines += ":固定付加文: \n"+
			doc.elements['//WarningComment[@codeType="固定付加文"]/Text'].text + "\n"
		lines += ":震源: "+doc.elements['//Hypocenter/Area/Name'].text + " "
		lines += NKF.nkf('-m0Z1 -w',doc.elements['//jmx_eb:Coordinate'].attributes["description"]) + "\n"
		lines += ":規模: "+NKF.nkf('-m0Z1 -w',doc.elements['//jmx_eb:Magnitude'].attributes["description"]) + "\n"
	elsif "沖合の津波観測に関する情報" == title then
		lines += ":タイトル: #{headtitle}\n"
		lines += ":見出し:   #{headline}\n"

		doc.elements.each('//Tsunami/Observation/Item') do |e|
			e.elements.each('Station') {|ee| 
				ee.elements.each('Name'){|eee| 
					lines += ":#{NKF.nkf('-m0Z1 -w',eee.text)}: "
					eee.elements.each('../MaxHeight/Condition'){|m|
						lines += "#{NKF.nkf('-m0Z1 -w',m.text)} "
					}
					eee.elements.each('../FirstHeight/ArrivalTime'){|m|
						arrv = Time.parse(NKF.nkf('-m0Z1 -w',m.text))
						lines += time.strftime("%H時%M分 ")
					}
					eee.elements.each('../Sensor'){|m| 
						lines += "[#{NKF.nkf('-m0Z1 -w',m.text)}] "
					}
				}
				lines += "\n"
			}
		end
		doc.elements.each('//Tsunami/Estimation/Item') do |e|
			e.elements.each('Area/Name'){|ee| 
				lines += ":#{ee.text}: "
			}
			e.elements.each('MaxHeight/Condition'){|ee| 
				lines += "**#{ee.text}** "
			}
			e.elements.each('MaxHeight/jmx_eb:TsunamiHeight'){|ee| 
				lines += ":#{ee.attributes['type']}: [#{ee.attributes['description']}]"
			}
			lines += "\n"
		end
		
		lines += ":固定付加文: \n"+
			doc.elements['//WarningComment[@codeType="固定付加文"]/Text'].text + "\n"
		lines += ":震源: "+doc.elements['//Hypocenter/Area/Name'].text + " "
		lines += NKF.nkf('-m0Z1 -w',doc.elements['//jmx_eb:Coordinate'].attributes["description"]) + "\n"
		lines += ":規模: "+NKF.nkf('-m0Z1 -w',doc.elements['//jmx_eb:Magnitude'].attributes["description"]) + "\n"

	end
	if tmp != lines then
		puts lines
		puts "===================================================="
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
