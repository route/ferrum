# frozen_string_literal: true

module Ferrum
  describe Node do
    it "raises an error if the element has been removed from the DOM" do
      browser.go_to("/ferrum/with_js")
      node = browser.at_css("#remove_me")
      expect(node.text).to eq("Remove me")
      browser.at_css("#remove").click
      expect { node.text }.to raise_error(Ferrum::NodeNotFoundError)
    end

    it "raises an error if the element was on a previous page" do
      browser.go_to("/ferrum/index")
      node = browser.at_xpath(".//a")
      browser.execute "window.location = 'about:blank'"
      expect { node.text }.to raise_error(Ferrum::NodeNotFoundError)
    end

    it "raises an error if the element is not visible" do
      browser.go_to("/ferrum/index")

      browser.execute <<~JS
        document.querySelector("a[href=js_redirect]").style.display = "none"
      JS

      sleep 0.2 # Wait for node to disappear

      expect {
        browser.at_xpath("//a[text()='JS redirect']").click
      }.to raise_error(
        Ferrum::CoordinatesNotFoundError,
        "Could not compute content quads"
      )
    end

    it "hovers an element before clicking it" do
      browser.go_to("/ferrum/with_js")
      browser.at_xpath("//a[span[text() = 'Hidden link']]").click
      expect(browser.current_url).to eq(base_url("/"))
    end

    it "works correctly when JSON is overwritten" do
      browser.go_to("/ferrum/index")
      browser.execute("JSON = {};")
      expect { browser.at_xpath("//a[text() = 'JS redirect']") }.not_to raise_error
    end

    it "#at_xpath searches relatively current node" do
      browser.go_to("/ferrum/with_js")

      p = browser.at_xpath("//p[@id='with_content']")

      expect(p.at_xpath("a").text).to eq("Open for match")
      expect(p.at_xpath(".//a").text).to eq("Open for match")
    end

    it "#xpath searches relatively current node" do
      browser.go_to("/ferrum/with_js")

      p = browser.at_xpath("//p[@id='with_content']")
      links = p.xpath("a")

      expect(links.size).to eq(1)
      expect(links.first.text).to eq("Open for match")
    end

    it "#at_css searches relatively current node" do
      browser.go_to("/ferrum/with_js")

      p = browser.at_css("p#with_content")

      expect(p.at_css("a").text).to eq("Open for match")
    end

    it "#css searches relatively current node" do
      browser.go_to("/ferrum/with_js")

      p = browser.at_xpath("//p[@id='with_content']")
      links = p.css("a")

      expect(links.size).to eq(1)
      expect(links.first.text).to eq("Open for match")
    end

    context "when the element is not in the viewport" do
      before do
        browser.go_to("/ferrum/with_js")
      end

      # FIXME:
      it "raises a MouseEventFailed error", skip: true do
        expect {
          browser.at_xpath("//a[text() = 'O hai']").click
        }.to raise_error(Ferrum::MouseEventFailed)
      end

      context "and is then brought in" do
        before do
          browser.execute %Q($("#off-the-left").animate({left: "10"});)
        end

        it "clicks properly" do
          expect { browser.at_xpath("//a[text() = 'O hai']") }.to_not raise_error
        end
      end
    end

    context "when the element is not in the viewport of parent element" do
      before do
        browser.go_to("/ferrum/scroll")
      end

      it "scrolls into view" do
        browser.at_xpath("//a[text() = 'Link outside viewport']").school_into_view.click
        expect(browser.current_url).to eq(base_url("/"))
      end

      it "scrolls into view if scrollIntoViewIfNeeded fails" do
        browser.at_xpath("//a[*//text() = 'Below the fold']").school_into_view.click
        expect(browser.current_url).to eq(base_url("/"))
      end
    end

    describe "Node#[]" do
      before do
        browser.go_to("/ferrum/attributes_properties")
      end

      it "gets normalized href" do
        expect(browser.at_xpath("//a[text() = 'Loop']").attribute("href"))
          .to eq("/ferrum/attributes_properties")
      end

      it "gets innerHTML" do
        expect(browser.at_css(".some_other_class").property("innerHTML")).to eq "<p>foobar</p>"
      end

      it "gets attribute" do
        link = browser.at_xpath("//a[text() = 'Loop']")
        expect(link.attribute("data-random")).to eq "42"
        expect(link.attribute("onclick")).to eq "return false;"
      end

      it "gets boolean attributes as booleans" do
        expect(browser.at_css("input#checked").property("checked")).to be true
        expect(browser.at_css("input#unchecked").property("checked")).to be false
      end
    end

    describe "Node#==" do
      it "does not equal a node from another page" do
        browser.go_to("/ferrum/simple")
        el1 = browser.at_css("#nav")
        browser.go_to("/ferrum/set")
        el2 = browser.at_css("#filled_div")
        expect(el2 == el1).to be false
        expect(el1 == el2).to be false
      end
    end

    describe "#focusable?" do
      before do
        browser.go_to("/ferrum/form")
      end

      context "with hidden input" do
        it { expect(browser.at_css("#hidden_input").focusable?).to eq(false) }
      end

      context "with regular input" do
        it { expect(browser.at_css("#form_name").focusable?).to eq(true) }
      end
    end
  end
end
