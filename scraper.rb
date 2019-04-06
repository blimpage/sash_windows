require "scraperwiki"
require "mechanize"
require_relative "send_mail"

raise "Notification email address is not set" if ENV["MORPH_NOTIFICATION_EMAIL_ADDRESS"].nil?
raise "Sendgrid API key is not set" if ENV["MORPH_SENDGRID_API_KEY"].nil?

ScraperWiki.config = { db: 'data.sqlite', default_table_name: 'data' }

agent = Mechanize.new

Product = Struct.new(:name, :description, :price, :url)

def build_product(element:, agent:)
  paragraphs = element.children.select { |el| el.name == "p" }
  name = paragraphs[0].inner_text.strip
  description = paragraphs[1].inner_text.strip

  price_element = element.children.detect { |el| el["class"] == "price" }
  price = price_element.inner_text.downcase

  link_element = element.children.detect { |el| el.name == "a" }
  href = link_element["href"]
  url = agent.agent.resolve(href).to_s

  Product.new(name, description, price, url)
end

def get_products_from_page(url:, agent:)
  puts "  Scraping page: #{url}"
  page = agent.get(url)

  product_elements = page.search(".product")
  puts "    #{product_elements.size} products found."

  product_elements.map { |element| build_product(element: element, agent: agent) }
end

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

main_page = agent.get("https://renovaterestorerecycle.com.au/index.php?subcat=6")

page_urls = main_page
  .at("#main_pane")
  .search("a")
  .select { |el| el.inner_text.downcase.include?("page") }
  .map { |el| el["href"] }
  .uniq
  .map { |url| agent.agent.resolve(url) }

puts "\n#{page_urls.size} pages found to scrape."

products = page_urls.flat_map { |page_url| get_products_from_page(url: page_url, agent: agent) }

available_products = products.reject do |product|
  product.price.include?("sold")
end

puts "\n#{available_products.size} total available products found."

existing_product_urls = load_existing_product_urls

new_products = available_products.reject do |potentially_new_product|
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
