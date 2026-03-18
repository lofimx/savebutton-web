# Configure SQLite to use string-based UUIDs
# SQLite doesn't have a native UUID type, so we store them as strings

if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.register_class_with_precision(
    ::ActiveRecord::Type::String,
    :uuid,
    limit: 36
  )

  # Monkey patch to ensure proper UUID handling
  module ActiveRecord
    module ConnectionAdapters
      module SQLite3
        module ColumnMethods
          def uuid(*args, **options)
            options[:limit] = 36
            args.each { |name| column(name, :string, **options) }
          end
        end
      end
    end
  end
end
