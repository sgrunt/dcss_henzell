require 'query/query_argument_normalizer'
require 'sql/query_sort_field'
require 'sql/query_group_filter'

module Query
  class RatioQueryFilter
    def self.parse(query, extra_field)
      arg_str = query.to_s
      filters = nil
      if arg_str =~ /\?:(.*)/
        filters = $1.strip
        query.argument_string = arg_str.sub(/\?:(.*)/, '').strip
      end

      parse_ratio_filters(filters, extra_field)
    end

    def self.parse_ratio_filters(filter_arg, extra_field)
      return [] unless filter_arg

      args = QueryArgumentNormalizer.normalize(filter_arg.split)
      args.map { |a| ratio_filter(a, extra_field) }
    end

    def self.ratio_filter(filter, extra)
      if filter !~ FILTER_PATTERN
        raise "Invalid ratio summary filter: #{filter}"
      end

      field, op, arg = $1, $2, $3.to_f
      field = Sql::QuerySortField.new(field, extra)
      Sql::QueryGroupFilter.new(field, op, arg)
    end
  end
end
