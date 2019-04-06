require "scraperwiki"
require "mechanize"

agent = Mechanize.new

# # Read in a page
page = agent.get("https://renovaterestorerecycle.com.au/index.php?subcat=6")

# # Find somehing on the page using css selectors
products = page.search(".product")

p "Products found: #{products.size}"

available_products = products.reject do |product|
  price_element = product.children.detect { |el| el["class"] == "price" }
  raise "no price found" unless price_element
  price = price_element.inner_text.downcase
  price.include?("sold")
end

p "Available products: #{available_products.size}"

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
