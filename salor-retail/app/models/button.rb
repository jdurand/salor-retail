# coding: UTF-8

# Salor -- The innovative Point Of Sales Software for your Retail Store
# Copyright (C) 2012-2013  Red (E) Tools LTD
# 
# See license.txt for the license applying to all files within this software.

class Button < ActiveRecord::Base
  include SalorScope
  include SalorBase
  include SalorModel

  belongs_to :category
  before_save :set_flags

  def category_sku=(sku)
    self.category = Category.where(:sku => sku).first
  end
  def category_sku
    return self.category.sku if self.category
  end
  def set_flags
    i = Item.find_by_sku self.sku
    self.is_buyback = true if i and i.default_buyback
  end
  
  def self.sort(buttons,type)
    type.map! {|t| t.to_i}
    buttons.each do |b|
      b.position ||= 0
      b.update_attribute :position, type.index(b.id) + 1 if type.index(b.id)
    end
    return buttons
  end
end
