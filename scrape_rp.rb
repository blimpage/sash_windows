require_relative "product"

module RP
  def self.get_products(agent:)
    puts "\nScraping renovatorsparadise.com.au:"

    products = []
    pages_scraped_count = 0

    start_page_url = "https://www.renovatorsparadise.com.au/product-category/windows/sash-window/traditional-art-deco/"

    current_page = agent.get(start_page_url)

    products_from_current_page = get_products_from_page(page: current_page, agent: agent)

    products += products_from_current_page
    pages_scraped_count += 1

    puts "\n  #{pages_scraped_count} pages scraped. #{products.count} total products found."

    products
  end

  def self.build_product(element:, agent:)
    name_element = element.search("h3").first
    name = name_element.inner_text.strip

    dimensions_element = element.search(".dim").first
    description = dimensions_element.inner_text.strip

    price_element = element.search(".price").first
    price = price_element.inner_text.strip

    link_element = element.search("a").first
    href = link_element["href"]
    url = agent.agent.resolve(href).to_s

    Product.new(name, description, price, url)
  end

  def self.get_products_from_page(page:, agent:)
    puts "  Scraping page: #{page.uri}"

    product_elements = page.search(".product")
    puts "    #{product_elements.size} products found."

    product_elements.map { |element| build_product(element: element, agent: agent) }
  end
end
