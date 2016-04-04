require 'net/http'
require 'json'
HOST = 'https://api.pearson.com'
MP3_HOST = 'http://api.pearson.com'
TMP_PATH = '/tmp/mydict'
`mkdir -p #{TMP_PATH}`

DICTIONARIES = {
    contemporary: 'ldoce5',
    en_cn: 'ldec',
    advanced_american: 'laad3',
    wordwise: 'wordwise',
    active_study: 'lasde'
}

def random_file_name(prefix = '', suffix = '')
  chars = ['a'..'z', 'A'..'Z', '0'..'9'].map(&:to_a).flatten
  ret = prefix
  30.times do
    ret += chars.sample
  end
  if suffix && suffix.size > 0
    ret += '.' + suffix
  end
  ret
end

def parse_pronunciation(pronunciations)
  ret = {}
  if pronunciations
    pronunciations.each do |p|
      audio = p['audio']
      ipa = p['ipa']
      bri = audio.find { |x| x['lang'] =~ /British/i }
      if bri
        ret[:bri_ipa] = ipa
        ret[:bri_url] = MP3_HOST + bri['url'] if bri['url']

      end
      ame = audio.find { |x| x['lang'] =~ /American/i }
      if ame
        ret[:ame_ipa] = ipa
        ret[:ame_url] = MP3_HOST + ame['url'] if ame['url']
      end
    end
  end
  ret
end

def word(w, dict = nil)
  dict ||= DICTIONARIES[:contemporary]
  first_time_limit = 10
  str = Net::HTTP.get(
      URI("#{MP3_HOST}/v2/dictionaries/#{dict}/entries?headword=#{w}&limit=#{first_time_limit}"))
  json = JSON.parse(str)
  json_results = json['results']
  return { status: :failed } if json_results.size <= 0
  total = json['total']
  results = []

  json_results.each do |result|
    word_entry = {}
    word_entry[:headword] = result['headword']
    word_entry[:part_of_speech] = result['part_of_speech']
    word_entry.merge!(parse_pronunciation(result['pronunciations']))
    if result['senses'] && result['senses'].size > 0
      sense = result['senses'].first
      if sense['definition']
        word_entry[:defs] = sense['definition'].join("\n")
      end
    end
    results << word_entry
  end
  results
end

def print_result(results)
  results.each_with_index do |r, i|
    first_line = "#{i}. #{r[:headword]}(#{r[:part_of_speech]})"
    puts first_line

    second_line = ''
    if r[:bri_ipa]
      second_line += "\u{1F50A} " if r[:bri_url]
      second_line += "BrE: #{r[:bri_ipa]}"
    end
    if r[:ame_ipa]
      second_line += "   \u{1F50A} " if r[:ame_url]
      second_line += "NAmE: #{r[:ame_ipa]}"
    end
    puts second_line
    if r[:defs]
      puts "definition: #{r[:defs]}"
    end
    puts '--------'
  end
end

if ARGV.size <= 0
  puts 'wrong command line'
  exit
end
results = word(ARGV[0])
print_result results
loop do
  opt = STDIN.gets
  case opt
    when /^(\d+)([a-z])?/i
      item = $1.to_i
      type = $2 =~ /b/i ? 'bri' : 'ame'
      r = results[item]
      if r
        url = "#{type}_url".to_sym
        ipa = "#{type}_ipa".to_sym
        if r[url] && r[ipa]
          puts "#{type}: /#{r[ipa]}/"
          `mpg123 -q #{r[url]}`
        end
      end
    when /^p/i
      print_result(results)
    else
      exit
  end
end

