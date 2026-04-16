package com.example.ead.be;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

@SpringBootTest
class ApplicationTests {

	@MockBean
	private ServiceController serviceController;

	@Test
	void contextLoads() {
	}

}
