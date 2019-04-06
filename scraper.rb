require "scraperwiki"
require "mechanize"

agent = Mechanize.new

Product = Struct.new(:name, :description, :price, :url)

ROOT_URL = "https://renovaterestorerecycle.com.au/"

def build_product(element:, agent:)
  paragraphs = element.children.select { |el| el.name == "p" }
  name = paragraphs[0].inner_text.strip
  description = paragraphs[1].inner_text.strip

  price_element = element.children.detect { |el| el["class"] == "price" }
  price = price_element.inner_text.downcase

  link_element = element.children.detect { |el| el.name == "a" }
  href = link_element["href"]
  url = agent.agent.resolve(href)

  Product.new(name, description, price, url)
end

def get_products_from_page(url:, agent:)
  page = agent.get(url)

  product_elements = page.search(".product")

  product_elements.map { |element| build_product(element: element, agent: agent) }
end

main_page = agent.get("#{ROOT_URL}index.php?subcat=6")

page_urls = main_page
  .at("#main_pane")
  .search("a")
  .select { |el| el.inner_text.downcase.include?("page") }
  .map { |el| el["href"] }
  .uniq
  .map { |url| agent.agent.resolve(url) }

p "page_urls: #{page_urls}"

products = page_urls.flat_map { |page_url| get_products_from_page(url: page_url, agent: agent) }

p "Products found: #{products.size}"

available_products = products.reject do |product|
  product.price.include?("sold")
end

p "Available products: #{available_products.size}"

available_products.each do |product|
  puts "\n--"
  puts "Name: #{product.name}"
  puts "Description: #{product.description}"
  puts "Price: #{product.price}"
  puts "URL: #{product.url}"
  puts "--"
end

# # Write out to the sqlite database using scraperwiki library
# ScraperWiki.save_sqlite(["name"], {"name" => "susan", "occupation" => "software developer"})
#
# # An arbitrary query against the database
# ScraperWiki.select("* from data where 'name'='peter'")

# You don't have to do things with the Mechanize or ScraperWiki libraries.
# You can use whatever gems you want: https://morph.io/documentation/ruby
# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".
