package com.example.ead.be;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;
import java.util.Properties;

import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ServiceControllerTest {

	private MockMvc mockMvc;
	private Persistence persistence;

	@BeforeEach
	void setUp() {
		ServiceController controller = new ServiceController();
		persistence = mock(Persistence.class);
		ReflectionTestUtils.setField(controller, "p", persistence);
		mockMvc = MockMvcBuilders.standaloneSetup(controller).build();
	}

	@Test
	void getRootReturnsGreeting() throws Exception {
		mockMvc.perform(get("/"))
				.andExpect(status().isOk())
				.andExpect(content().string(containsString("Greetings from EAD CA2")));
	}

	@Test
	void getHealthReturnsOk() throws Exception {
		mockMvc.perform(get("/health"))
				.andExpect(status().isOk())
				.andExpect(content().string("OK"));
	}

	@Test
	void getRecipesReturnsJsonArray() throws Exception {
		when(persistence.getAllRecipes()).thenReturn(List.of(
				new Recipe("toast", List.of("bread", "butter"), 5)
		));

		mockMvc.perform(get("/recipes"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].name").value("toast"))
				.andExpect(jsonPath("$[0].ingredients[0]").value("bread"))
				.andExpect(jsonPath("$[0].prepTimeInMinutes").value(5));
	}

	@Test
	void postRecipeReturnsCreated() throws Exception {
		when(persistence.addRecipes(anyList())).thenReturn(1);

		MockHttpServletResponse response = mockMvc.perform(post("/recipe")
						.contentType("application/json")
						.content("""
								{
								  "name": "pasta",
								  "ingredients": ["pasta", "tomato"],
								  "prepTimeInMinutes": 20
								}
								"""))
				.andExpect(status().isCreated())
				.andReturn()
				.getResponse();

		verify(persistence).addRecipes(anyList());
		org.junit.jupiter.api.Assertions.assertEquals("1", response.getContentAsString());
	}

	@Test
	void applicationPropertiesContainDatabasePlaceholders() throws Exception {
		Properties properties = new Properties();
		try (var inputStream = new ClassPathResource("application.properties").getInputStream()) {
			properties.load(inputStream);
		}

		org.junit.jupiter.api.Assertions.assertTrue(properties.getProperty("databaseUrl").contains("${DATABASE_URL"));
		org.junit.jupiter.api.Assertions.assertTrue(properties.getProperty("databaseName").contains("${DATABASE_NAME"));
		org.junit.jupiter.api.Assertions.assertTrue(properties.getProperty("databaseCollection").contains("${DATABASE_COLLECTION"));
	}
}
