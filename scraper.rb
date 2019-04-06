require "scraperwiki"
require "mechanize"

ScraperWiki.config = { db: 'data.sqlite', default_table_name: 'data' }

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
  url = agent.agent.resolve(href).to_s

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

products = page_urls.flat_map { |page_url| get_products_from_page(url: page_url, agent: agent) }

available_products = products.reject do |product|
  product.price.include?("sold")
end

available_products.each do |product|
  ScraperWiki.save_sqlite([:url], product.to_h)
end

puts "#{available_products.size} available products written to the DB. Bye!"
