require_relative "product"

module RRR
  def self.get_products(agent:)
    puts "\nScraping renovaterestorerecycle.com.au:"

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

    puts "\n  #{pages_scraped_count} pages scraped. #{products.count} total products found."

    available_products = products.reject do |product|
      product.price.include?("sold")
    end

    puts "\n  #{available_products.size} available product(s) found."

    available_products
  end

  def self.build_product(element:, agent:)
    name_element = element.children.detect { |el| el["class"] == "entry-title" }
    name = name_element.inner_text.strip

    product_info_element = element.children.detect { |el| el["class"] == "product-info" }

    description_elements = product_info_element.children.reject { |el| el["class"] == "price" }
    description = description_elements.map(&:inner_text).map(&:strip).reject(&:empty?).join(" ")

    price_element = product_info_element.children.detect { |el| el["class"] == "price" }
    price = price_element.inner_text.downcase

    link_element = element.children.detect { |el| el.name == "a" }
    href = link_element["href"]
    url = agent.agent.resolve(href).to_s

    Product.new(name, description, price, url)
  end

  def self.get_products_from_page(page:, agent:)
    puts "  Scraping page: #{page.uri}"

    product_elements = page.search("article.type-rrr_stock")
    puts "    #{product_elements.size} products found."

    product_elements.map { |element| build_product(element: element, agent: agent) }
  end

  def self.get_next_page_url_from_page(page:, agent:)
    next_page_link = page.at("a.page-numbers.next")

    return nil if next_page_link.nil?

    agent.agent.resolve(next_page_link["href"])
  end
end
