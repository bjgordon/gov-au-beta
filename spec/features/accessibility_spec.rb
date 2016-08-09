require 'rails_helper'
require 'open-uri'

RSpec.describe 'accessibility:', :js, :truncate, :nodes_helper, type: :feature do

  Warden.test_mode!
  WebMock.allow_net_connect!

  shared_examples 'is accessible' do |url, as_code|
    it "#{url} is accessible" do
      if as_code
        url = eval(url)
      end
      visit url
      expect(page.status_code).to eq(200)
      # TODO: Remove skip clause once ui-kit colours are updated
      # See https://github.com/AusDTO/gov-au-ui-kit/issues/271
      expect(page).to be_accessible.according_to(:wcag2a, :wcag2aa).skipping('color-contrast')
    end
  end

  shared_examples 'is accessible sitemap' do |uri|
    sitemap = open(uri) { |f| Nokogiri::XML(f) }
    sitemap.css('url loc').each do |loc_block|
      url = loc_block.content
      if ENV.has_key?('ACCESSIBILITY_TEST_HOST')
        url = url.gsub('http://localhost:3000', ENV['ACCESSIBILITY_TEST_HOST'])
      end
      include_examples 'is accessible', url
    end
    sitemap.css('sitemap loc').each do |sitemap_block|
      url = sitemap_block.content
      if ENV.has_key?('ACCESSIBILITY_TEST_HOST')
        url = url.gsub('http://localhost:3000', ENV['ACCESSIBILITY_TEST_HOST'])
      end
      include_examples 'is accessible sitemap', url
    end
  end

  if ENV.has_key?('ACCESSIBILITY_TEST_URL')

    # Test accessibility of a given URL
    include_examples 'is accessible', ENV['ACCESSIBILITY_TEST_URL']

  elsif ENV.has_key?('ACCESSIBILITY_TEST_SITEMAP')

    # Test accessibility of all urls in a sitemap
    include_examples 'is accessible sitemap', ENV['ACCESSIBILITY_TEST_SITEMAP']

  else

    # Test accessibility of test data
    let!(:minister) { Fabricate(:minister) }
    let!(:department) { Fabricate(:department, ministers: [minister]) }
    let!(:topic) { Fabricate(:topic) }
    let!(:news_article) { Fabricate(:news_article, section: department, sections: [department, minister]) }
    let!(:general_content) { Fabricate(:general_content) }
    include_examples 'is accessible', 'root_path', true
    include_examples 'is accessible', 'departments_path', true
    include_examples 'is accessible', 'ministers_path', true
    include_examples 'is accessible', 'news_articles_path', true
    include_examples 'is accessible', 'public_node_path(news_article)', true
    include_examples 'is accessible', 'public_node_path(department.home_node)', true
    include_examples 'is accessible', 'public_node_path(minister.home_node)', true
    include_examples 'is accessible', 'public_node_path(topic.home_node)', true
    include_examples 'is accessible', 'public_node_path(general_content)', true

  end
end
