class SynergyNode < ApplicationRecord
  extend ActsAsTree::TreeView
  extend ActsAsTree::TreeWalker

  acts_as_tree order: 'position ASC'

  before_save :set_path!

  def name
    title || (slug.blank? ? 'Home' : slug.underscore.humanize)
  end

  private

  def set_path!
    if self.parent.present?
      self.path = self.self_and_ancestors.map(&:slug).reverse.join('/')
    else
      self.path = '/'
    end
  end
end