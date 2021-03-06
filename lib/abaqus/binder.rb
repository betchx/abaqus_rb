
unless defined?(ABAQUS_BINDER_RB)
  ABAQUS_BINDER_RB = true

  module Abaqus
    module Binder
      module_function
      def inject_bind_methods(target)
        target.module_eval do
          begin
            class_variable_get(:@@method)
          rescue
            class_variable_set(:@@method, self.name.split(/::/).pop.downcase + "s")
          end
          class_variable_set(:@@old_bind, [])# unless defined?(:@@old_bind)
          class_variable_set(:@@all, {})# unless defined?(:@@all)
          class_variable_set(:@@old_parent, [])
          class_variable_set(:@@parent, "")
          def self.parent
            class_variable_get(:@@parent)
          end
          def parent
            class_variable_get(:@@parent)
          end
          def self.bind(model)
            class_variable_get(:@@old_bind) << class_variable_get(:@@all)
            class_variable_set(:@@all,
                               model.__send__(class_variable_get(:@@method)))
            class_variable_get(:@@old_parent) << class_variable_get(:@@parent)
            class_variable_set(:@@parent, model)
            #p self.class_variables
            reset if defined?(reset)
          end
          def self.release
            class_variable_set(:@@all, class_variable_get(:@@old_bind).pop)
            class_variable_set(:@@parent, class_variable_get(:@@old_parent).pop)
          end
          def self.with_bind(model)
            self.bind(model)
            yield
            self.release
          end
        end
      end
    end
  end

end
