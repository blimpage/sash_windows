require "scraperwiki"
require "mechanize"
require_relative "scrape_rrr"
require_relative "send_mail"

raise "Notification email address is not set" if ENV["MORPH_NOTIFICATION_EMAIL_ADDRESS"].nil?
raise "Sendgrid API key is not set" if ENV["MORPH_SENDGRID_API_KEY"].nil?

ScraperWiki.config = { db: 'data.sqlite', default_table_name: 'data' }

agent = Mechanize.new

def load_existing_product_urls
  ScraperWiki.select("* from data")
    .map { |existing_product| existing_product["url"] }
rescue # If the database table doesn't exist yet, SQLite will raise an error
  []
end

def generate_mail_content(new_products:)
  header = "Hey, I found some new sash windows for you!"
  footer = "Okay bye!<br />https://morph.io/blimpage/sash_windows"
  separator = "<br /><br />--<br /><br />"

  product_texts = new_products.map do |product|
    <<~HEREDOC
      <strong>Name:</strong> #{product.name}<br />
      <strong>Description:</strong> #{product.description}<br />
      <strong>Price:</strong> #{product.price}<br />
      <strong>URL:</strong> <a href="#{product.url}">#{product.url}</a>
    HEREDOC
  end

  [header, product_texts.join(separator), footer].join(separator)
end

products = RRR.get_products(agent: agent)

existing_product_urls = load_existing_product_urls

new_products = products.reject do |potentially_new_product|
  existing_product_urls.include?(potentially_new_product.url)
end

if new_products.any?
  puts "\n#{new_products.size} new product(s) found!"

  mail_content = generate_mail_content(new_products: new_products)
  send_mail(html_content: mail_content)

  new_products.each do |product|
    ScraperWiki.save_sqlite([:url], product.to_h)
  end

  puts "  New products saved to the database."

  puts "\nAll done! Bye!"
else
  puts "\nNo new products found. Oh well. Seeya."
end
