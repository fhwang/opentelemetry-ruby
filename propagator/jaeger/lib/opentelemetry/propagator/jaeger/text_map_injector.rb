# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0
module OpenTelemetry
  # Namespace for OpenTelemetry propagator extension libraries
  module Propagator
    # Namespace for OpenTelemetry Jaeger propagation
    module Jaeger
      # Injects context into carriers
      class TextMapInjector
        DEFAULT_FLAG_BIT = 0b0
        SAMPLED_FLAG_BIT = 0b01
        DEBUG_FLAG_BIT   = 0b10

        # Returns a new TextMapInjector that extracts Jaeger context using the
        # specified header keys
        #
        # @param [optional Setter] default_setter The default setter used to
        #   write context into a carrier during inject. Defaults to a
        #   {OpenTelemetry::Context:Propagation::TextMapSetter} instance.
        # @return [TextMapInjector]
        def initialize(default_setter = Context::Propagation.text_map_setter)
          @default_setter = default_setter
        end

        # Set the span context on the supplied carrier.
        #
        # @param [Context] context The active Context.
        # @param [optional Callable] setter An optional callable that takes a
        #   carrier and a key and a value and assigns the key-value pair in the
        #   carrier. If omitted the default setter will be used which expects
        #   the carrier to respond to [] and []=.
        # @yield [Carrier, String, String] if an optional setter is provided,
        #   inject will yield carrier, header key, header value to the setter.
        # @return [Object] the carrier with context injected
        def inject(carrier, context, &setter)
          span_context = Trace.current_span(context).context
          return unless span_context.valid?

          flags = to_flags(context, span_context)
          trace_span_identity_value = [
            span_context.hex_trace_id, span_context.hex_span_id, '0', flags
          ].join(':')
          setter ||= @default_setter
          setter.set(carrier, IDENTITY_KEY, trace_span_identity_value)
          OpenTelemetry.baggage.values(context: context).each do |key, value|
            baggage_key = 'uberctx-' + key
            setter.set(carrier, baggage_key, value)
          end
          carrier
        end

        private

        def to_flags(context, span_context)
          if span_context.trace_flags == TraceFlags::SAMPLED
            if Jaeger.debug?(context)
              SAMPLED_FLAG_BIT | DEBUG_FLAG_BIT
            else
              SAMPLED_FLAG_BIT
            end
          else
            DEFAULT_FLAG_BIT
          end
        end
      end
    end
  end
end
