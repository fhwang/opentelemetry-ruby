# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'

describe OpenTelemetry::Trace::Propagation::TraceContext::TextMapExtractor do
  let(:traceparent_key) { 'traceparent' }
  let(:tracestate_key) { 'tracestate' }
  let(:extractor) do
    OpenTelemetry::Trace::Propagation::TraceContext::TextMapExtractor.new(
      traceparent_key: traceparent_key,
      tracestate_key: tracestate_key
    )
  end
  let(:valid_traceparent_header) do
    '00-000000000000000000000000000000AA-00000000000000ea-01'
  end
  let(:invalid_traceparent_header) do
    'FF-000000000000000000000000000000AA-00000000000000ea-01'
  end
  let(:tracestate_header) { 'vendorname=opaquevalue' }
  let(:tracestate) { OpenTelemetry::Trace::Tracestate.from_hash('vendorname' => 'opaquevalue') }
  let(:carrier) do
    {
      traceparent_key => valid_traceparent_header,
      tracestate_key => tracestate_header
    }
  end
  let(:context) { Context.empty }

  describe '#extract' do
    it 'yields the carrier and the header key' do
      yielded_keys = []
      extractor.extract(carrier, context) do |c, key|
        _(c).must_equal(carrier)
        yielded_keys << key
        c[key]
      end
      _(yielded_keys.sort).must_equal([traceparent_key, tracestate_key])
    end

    it 'returns a remote SpanContext with fields from the traceparent and tracestate headers' do
      ctx = extractor.extract(carrier, context) { |c, k| c[k] }
      span_context = OpenTelemetry::Trace.current_span(ctx).context
      _(span_context).must_be :remote?
      _(span_context.trace_id).must_equal(("\0" * 15 + "\xaa").b)
      _(span_context.span_id).must_equal(("\0" * 7 + "\xea").b)
      _(span_context.trace_flags).must_be :sampled?
      _(span_context.tracestate).must_equal(tracestate)
    end

    it 'uses a default getter if one is not provided' do
      ctx = extractor.extract(carrier, context)
      span_context = OpenTelemetry::Trace.current_span(ctx).context
      _(span_context).must_be :remote?
      _(span_context.trace_id).must_equal(("\0" * 15 + "\xaa").b)
      _(span_context.span_id).must_equal(("\0" * 7 + "\xea").b)
      _(span_context.trace_flags).must_be :sampled?
      _(span_context.tracestate).must_equal(tracestate)
    end

    it 'returns original context on error' do
      ctx = extractor.extract({}, context) { invalid_traceparent_header }
      _(ctx).must_equal(context)
    end
  end
end
