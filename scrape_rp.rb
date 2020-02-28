require_relative "product"

module RP
  def self.get_products(agent:)
    puts "\nScraping renovatorsparadise.com.au:"

    products = []
    pages_scraped_count = 0

    start_page_url = "https://www.renovatorsparadise.com.au/product-category/windows/"

    puts "  Finding pages to scrape."
    page_urls = get_page_urls(starting_page: agent.get(start_page_url), agent: agent)
    puts "    #{page_urls.size} page(s) of interest found.\n\n"


    products = []
    pages_scraped_count = 0

    page_urls.each do |page_url|
      current_page = agent.get(page_url)

      products_from_current_page = get_products_from_page(page: current_page, agent: agent)

      products += products_from_current_page
      pages_scraped_count += 1
    end

    puts "\n  #{pages_scraped_count} pages scraped. #{products.count} total products found."

    products
  end

  def self.build_product(element:, agent:)
    name_element = element.search("h3").first
    name = name_element.inner_text.strip

    dimensions_element = element.search(".dim").first
    description = dimensions_element.inner_text.strip

    # The price element can either contain just the price, or might contain both a
    # <del> element with the original price and an <ins> element with a markdown price.
    # If there's a markdown price then we want only that, otherwise the entire inner_text.
    price_element = element.search(".price").first
    markdown_price_element = price_element.search("ins")&.first
    price = (markdown_price_element || price_element).inner_text.strip

    link_element = element.search("a").first
    href = link_element["href"]
    url = agent.agent.resolve(href).to_s

    Product.new(name, description, price, url)
  end

  def self.get_products_from_page(page:, agent:)
    puts "  Scraping page: #{page.uri}"

    product_elements = page.search(".product")
    puts "    #{product_elements.size} product(s) found."

    product_elements.map { |element| build_product(element: element, agent: agent) }
  end

  def self.get_page_urls(starting_page:, agent:)
    categories = starting_page.search(".product-category")

    if categories.empty?
      # We've reached a page with products on it, so return the current page URL
      return [starting_page.uri]
    end

    categories_we_care_about = categories.select do |category|
      title = category.search("h2").first.inner_text.strip.downcase

      should_include = category_words_to_include.any? { |word| title.include?(word) }
      should_exclude = category_words_to_exclude.any? { |word| title.include?(word) }

      should_include && !should_exclude
    end

    page_urls = categories_we_care_about.map do |category|
      category_url = agent.agent.resolve(category.search("a").first["href"])

      # Recursively call this method to go through all the pages until we find product listings.
      get_page_urls(starting_page: agent.get(category_url), agent: agent)
    end

    page_urls.flatten
  end

  def self.category_words_to_include
    [
      "sash",
      "interwar",
      "art deco",
    ]
  end

  def self.category_words_to_exclude
    [
      "colonial",
      "sashes", # ignore categories that are just sashes without a casement
    ]
  end
end
