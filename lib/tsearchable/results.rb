module TSearchable
  class Results < Array
    attr_reader :current_page, :per_page, :total_entries

    def initialize(page, per_page, total = nil)
      @current_page = page.to_i
      @per_page = per_page.to_i
      self.total_entries = total if total
    end

    def self.create(page, per_page, total = nil, &block)
      pager = new(page, per_page, total)
      yield pager
      pager
    end

    def page_count
      @total_pages
    end

    def previous_page
      current_page > 1 ? (current_page - 1) : nil
    end

    def next_page
      current_page < page_count ? (current_page + 1) : nil
    end

    def offset
      (current_page - 1) * per_page
    end

    def total_entries=(number)
      @total_entries = number.to_i
      @total_pages   = (@total_entries / per_page.to_f).ceil
    end

    def replace(array)
      returning super do
        if total_entries.nil? and length > 0 and length < per_page
          self.total_entries = offset + length
        end
      end
    end
  end
end
