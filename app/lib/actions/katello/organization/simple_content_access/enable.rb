module Actions
  module Katello
    module Organization
      module SimpleContentAccess
        class Enable < Toggle
          def content_access_mode_value
            SIMPLE_CONTENT_ACCESS_ENABLED_VALUE
          end

          def humanized_name
            N_("Enable Simple Content Access")
          end
        end
      end
    end
  end
end
