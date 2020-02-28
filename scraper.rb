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

def get_products_from_page(page:, agent:)
  puts "  Scraping page: #{page.uri}"

  product_elements = page.search(".product")
  puts "    #{product_elements.size} products found."

  product_elements.map { |element| build_product(element: element, agent: agent) }
end

def get_next_page_url_from_page(page:, agent:)
  next_page_link = page.at("a.page-numbers.next")

  return nil if next_page_link.nil?

  agent.agent.resolve(next_page_link["href"])
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

products = []
pages_scraped_count = 0

start_page_url = "https://www.renovaterestorerecycle.com.au/category/sash-windows/?post_type=rrr_stock"
next_page_url = start_page_url

until next_page_url.nil? do
  current_page = agent.get(next_page_url)

  products_from_current_page = get_products_from_page(page: current_page, agent: agent)

  products += products_from_current_page
  pages_scraped_count += 1

  next_page_url = get_next_page_url_from_page(page: current_page, agent: agent)
end

puts "\n#{pages_scraped_count} pages scraped."

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
