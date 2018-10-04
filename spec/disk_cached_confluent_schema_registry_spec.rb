require 'webmock/rspec'
require 'avro_turf/cached_confluent_schema_registry'
require 'avro_turf/test/fake_confluent_schema_registry_server'

describe AvroTurf::CachedConfluentSchemaRegistry do
  let(:upstream) { instance_double(AvroTurf::ConfluentSchemaRegistry) }
  let(:registry) { described_class.new(upstream, disk_path: "spec/cache") }
  let(:id) { rand(999) }
  let(:schema) do
    {
      type: "record",
      name: "person",
      fields: [{ name: "name", type: "string" }]
    }.to_json
  end

  let(:city_id) { rand(999) }
  let(:city_schema) do
    {
      type: "record",
      name: "city",
      fields: [{ name: "name", type: "string" }]
    }.to_json
  end

  before do
    FileUtils.mkdir_p("spec/cache")
  end

  describe "#fetch" do
    let(:cache_before) do
      {
        "#{id}" => "#{schema}"
      }
    end
    let(:cache_after) do
      {
        "#{id}" => "#{schema}",
        "#{city_id}" => "#{city_schema}"
      }
    end

    # setup the disk cache to avoid performing the upstream fetch
    before do
      store_cache("schemas_by_id.json", cache_before)
    end

    it "uses preloaded disk cache" do
      # multiple calls return same result, with zero upstream calls
      allow(upstream).to receive(:fetch).with(id).and_return(schema)
      expect(registry.fetch(id)).to eq(schema)
      expect(registry.fetch(id)).to eq(schema)
      expect(upstream).to have_received(:fetch).exactly(0).times
      expect(load_cache("schemas_by_id.json")).to eq cache_before
    end

    it "writes thru to disk cache" do
      # multiple calls return same result, with only one upstream call
      allow(upstream).to receive(:fetch).with(city_id).and_return(city_schema)
      expect(registry.fetch(city_id)).to eq(city_schema)
      expect(registry.fetch(city_id)).to eq(city_schema)
      expect(upstream).to have_received(:fetch).exactly(1).times
      expect(load_cache("schemas_by_id.json")).to eq cache_after
    end
  end

  describe "#register" do
    let(:subject_name) { "a_subject" }
    let(:cache_before) do
      {
        "#{subject_name}#{schema}" => id
      }
    end

    let(:city_name) { "a_city" }
    let(:cache_after) do 
      {
        "#{subject_name}#{schema}" => id,
        "#{city_name}#{city_schema}" => city_id
      }
    end

    # setup the disk cache to avoid performing the upstream register
    before do
      store_cache("ids_by_schema.json", cache_before)
    end

    it "uses preloaded disk cache" do
      # multiple calls return same result, with zero upstream calls
      allow(upstream).to receive(:register).with(subject_name, schema).and_return(id)
      expect(registry.register(subject_name, schema)).to eq(id) 
      expect(registry.register(subject_name, schema)).to eq(id)
      expect(upstream).to have_received(:register).exactly(0).times
      expect(load_cache("ids_by_schema.json")).to eq cache_before
    end

    it "writes thru to disk cache" do
      # multiple calls return same result, with only one upstream call
      allow(upstream).to receive(:register).with(city_name, city_schema).and_return(city_id)
      expect(registry.register(city_name, city_schema)).to eq(city_id)
      expect(registry.register(city_name, city_schema)).to eq(city_id)
      expect(upstream).to have_received(:register).exactly(1).times
      expect(load_cache("ids_by_schema.json")).to eq cache_after
    end
  end

  it_behaves_like "a confluent schema registry client" do
    let(:upstream) { AvroTurf::ConfluentSchemaRegistry.new(registry_url, logger: logger) }
    let(:registry) { described_class.new(upstream) }
  end
end
